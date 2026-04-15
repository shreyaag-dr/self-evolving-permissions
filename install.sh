#!/bin/bash
# install.sh
# Adds the permission-logger hooks to ~/.claude/settings.json
# and installs the audit skill to ~/.claude/commands/

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$REPO_DIR/hooks/permission-logger.py"
SETTINGS="$HOME/.claude/settings.json"
COMMANDS_DIR="$HOME/.claude/commands"

echo "Installing self-evolving-permissions..."
echo ""

# Make hook executable
chmod +x "$HOOK_SCRIPT"

# Install hooks into settings.json
python3 - <<PYEOF
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_script = "$HOOK_SCRIPT"
hook_entry = {"type": "command", "command": f"python3 {hook_script}"}

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault("hooks", {})

for event in ("PermissionRequest", "PermissionDenied"):
    event_hooks = hooks.setdefault(event, [])
    already = any(
        hook_entry["command"] in str(h)
        for h in event_hooks
    )
    if not already:
        event_hooks.append({
            "matcher": "",
            "hooks": [hook_entry]
        })
        print(f"  [+] Hooked {event}")
    else:
        print(f"  [=] {event} already hooked, skipping")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

log_dir = os.path.expanduser("~/.claude/logs")
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, "permission-prompts.jsonl")
if not os.path.exists(log_file):
    open(log_file, "w").close()
    print(f"  [+] Created log file: {log_file}")
else:
    print(f"  [=] Log file already exists: {log_file}")
PYEOF

# Install audit skill to ~/.claude/commands/
mkdir -p "$COMMANDS_DIR"
cp "$REPO_DIR/skills/permission-audit.md" "$COMMANDS_DIR/permission-audit.md"
echo "  [+] Installed /permission-audit skill"

echo ""
echo "Done. Start a new Claude Code session for hooks to take effect."
echo ""
echo "Usage:"
echo "  - Hooks run automatically. Just use Claude Code normally."
echo "  - Run /permission-audit in any session to get your audit report."
echo "  - Logs: ~/.claude/logs/permission-prompts.jsonl"
