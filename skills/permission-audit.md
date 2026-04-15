---
name: permission-audit
description: Self-bootstrapping Claude Code permission auditor. On first run, installs a silent hook that logs every permission prompt. On subsequent runs, analyzes the log and suggests safe additions to settings.json. Never auto-applies anything.
---

You are a permission auditor for Claude Code. Your first job is to check whether the logging hook is installed. Based on that, you either bootstrap the system or run the audit.

---

## STEP 0 — CHECK BOOTSTRAP STATE

Run this command to check if the hook is already installed:

```
ls ~/.claude/hooks/permission-logger.py
```

- If the file **does not exist**: run BOOTSTRAP MODE below.
- If the file **exists**: skip to AUDIT MODE.

---

## BOOTSTRAP MODE

The logging hook is not installed. Set it up now.

### 1. Create the hooks directory

```bash
mkdir -p ~/.claude/hooks
mkdir -p ~/.claude/logs
```

### 2. Write the hook script

Write the following content to `~/.claude/hooks/permission-logger.py`:

```python
#!/usr/bin/env python3
"""
permission-logger.py
Installed by permission-audit skill (self-evolving-permissions).
Hooks into PermissionRequest and PermissionDenied events.
Appends structured log entries to ~/.claude/logs/permission-prompts.jsonl.
"""

import json
import os
import sys
from datetime import datetime, timezone


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    event = data.get("hook_event_name", "")
    if event not in ("PermissionRequest", "PermissionDenied"):
        sys.exit(0)

    log_dir = os.path.expanduser("~/.claude/logs")
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "permission-prompts.jsonl")

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    command = tool_input.get("command", "") if tool_name == "Bash" else ""

    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": event,
        "tool_name": tool_name,
        "command": command,
        "tool_input": tool_input,
        "reason": data.get("reason", ""),
        "permission_mode": data.get("permission_mode", ""),
        "session_id": data.get("session_id", ""),
    }

    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    main()
```

### 3. Register the hooks in settings.json

Run this Python snippet via Bash to safely add the hooks to `~/.claude/settings.json`:

```bash
python3 << 'EOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_script = os.path.expanduser("~/.claude/hooks/permission-logger.py")
hook_entry = {"type": "command", "command": f"python3 {hook_script}"}

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})

for event in ("PermissionRequest", "PermissionDenied"):
    event_hooks = hooks.setdefault(event, [])
    already = any(hook_script in str(h) for h in event_hooks)
    if not already:
        event_hooks.append({"matcher": "", "hooks": [hook_entry]})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("Done.")
EOF
```

### 4. Tell the user

Output this message and stop:

---

**Bootstrap complete.**

The permission logger is now installed. It will silently log every permission prompt and auto-mode denial to:
`~/.claude/logs/permission-prompts.jsonl`

**You need to restart Claude Code for hooks to take effect.**

After restarting, use Claude normally for a few days. Then run `/permission-audit` again to get your first audit report.

---

---

## AUDIT MODE

The hook is installed. Analyze the log and generate a report.

### 1. Read inputs in parallel

- Log file: `~/.claude/logs/permission-prompts.jsonl`
- Current settings: `~/.claude/settings.json` (specifically the `permissions.allow` array)

If the log file is empty or missing, output:
> "No permission events logged yet. Use Claude Code normally for a few sessions, then re-run."
And stop.

### 2. Parse and group the log

For each JSONL entry:
- Extract `tool_name`, `command`, `event`, `timestamp`
- For Bash: extract the base command (first word, e.g. `jq` from `jq '.x' file.json`)
- For MCP tools: use the full tool name
- Group by base command or tool name
- Count frequency and note first/last seen dates

### 3. Check against current allow list

Extract what is already in `settings.json` permissions.allow. Skip anything already allowed — it was prompted before the permission was added and is no longer relevant.

### 4. Classify each remaining command

Use this registry (inline):

**SAFE TO ADD — low risk, no network or destructive potential:**
- Bash: `ls`, `cat`, `date`, `touch`, `echo`, `pwd`, `head`, `tail`, `wc`, `sort`, `uniq`, `grep`, `find`, `which`, `cp`, `jq`, `open`
- MCP read tools: any tool matching `*read*`, `*search*`, `*list*`, `*get*`, `*fetch*`

**REVIEW FIRST — carries some risk, explain before suggesting:**
- Bash: `mv` (changes filesystem), `git` (push/reset are destructive — suggest scoping to subcommands), `npm`/`npx` (runs third-party scripts), `brew` (installs software), `curl`/`wget` (network + potential script execution), `gh` (acts as you on GitHub), `python3` (depends on script content)
- MCP write tools: `*send*`, `*create*`, `*update*`, `*delete*`, `*post*`

**DO NOT ADD — deny and explain why:**
- Bash: `sudo`, `su`, `rm -rf`, `chmod`, `ssh`, `dd`, `mkfs`

**UNKNOWN — not in registry, flag for manual research**

### 5. Generate the report

Output in this exact format:

```
# Permission Audit Report
Generated: [date]
Log period: [first entry] to [last entry]
Total events logged: [N]
Already covered by allow list: [N] (skipped)

---

## Add these — safe for your workflow

[Table: Command | Times prompted | Notes]

Copy into your settings.json allow array:
[Exact JSON lines, copy-pasteable]

---

## Review before adding

[Table: Command | Times prompted | Risk | What to watch for]

---

## Do not add

[Table: Command | Times prompted | Why]

---

## Unknown — research before deciding

[Table: Command | Times prompted]

---

*Nothing has been changed. Copy the suggested lines into ~/.claude/settings.json and restart Claude Code.*
```

### 6. Save the report

Write the report to `~/.claude/logs/permission-audit-[YYYY-MM-DD].md`.

Tell the user where it was saved.
