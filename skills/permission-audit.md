---
name: permission-audit
description: Audit Claude Code permission prompts and suggest safe additions to settings.json. Never auto-applies. Always requires human approval.
---

You are running a permission audit for Claude Code. Your job is to analyze what commands have been triggering permission prompts, cross-reference against a curated safety registry, and produce a clear human-readable report with specific suggestions. You never modify settings.json yourself — the user decides what to apply.

---

## STEP 1 — LOAD CONTEXT

Read the following in parallel:

1. The permission log: `~/.claude/logs/permission-prompts.jsonl`
2. Current settings: `~/.claude/settings.json`
3. Bash registry: Read the `registry/bash-safe.json` file from the self-evolving-permissions repo (check `~/workspace/self-evolving-permissions/registry/bash-safe.json`)
4. MCP registry: `~/workspace/self-evolving-permissions/registry/mcp-safe.json`

If the log file is empty or missing, output: "No permission events logged yet. Use Claude Code normally for a few days, then re-run this audit."

---

## STEP 2 — ANALYZE THE LOG

Parse each line of the JSONL log. For each entry:

- Extract: `tool_name`, `command` (for Bash), `mcp_tool`, `event` (PermissionRequest vs PermissionDenied), `timestamp`
- For Bash commands, extract the base command (first word, e.g. `jq` from `jq '.items[]' file.json`)
- Group by base command or MCP tool name
- Count frequency: how many times each was prompted
- Note date range: first seen, last seen

---

## STEP 3 — CLASSIFY AGAINST REGISTRY

For each unique command/tool that appeared in the log:

1. Check if it is already in the current `settings.json` allow list. If yes, skip it (it was prompted before the permission was added).
2. Look it up in the registry. Classify as:
   - **SAFE TO ADD** — registry says safe, no destructive potential
   - **REVIEW FIRST** — registry says review, explain why and what to watch for
   - **DO NOT ADD** — registry says deny, explain the risk
   - **UNKNOWN** — not in registry, flag for manual research

---

## STEP 4 — GENERATE REPORT

Output a clean markdown report in this format:

```
# Permission Audit Report
Generated: [date]
Log period: [first entry date] to [last entry date]
Total permission events: [N]

---

## Recommended additions to settings.json

These commands triggered prompts repeatedly and are safe to add for your workflow.

| Command | Prompted | Risk | Notes |
|---------|----------|------|-------|
| Bash(jq:*) | 14x | Safe | JSON parsing, read-only |
| Bash(cp:*) | 6x | Safe | File copy, non-destructive |

Suggested diff for settings.json:
[Show exact JSON lines to add to the allow array, copy-pasteable]

---

## Review before adding

These triggered prompts but carry some risk. Read the notes before deciding.

| Command | Prompted | Risk | Notes |
|---------|----------|------|-------|
| Bash(curl:*) | 3x | Review | Can make network requests. Consider Bash(curl -s:*) or deny entirely. |

---

## Do not add

| Command | Prompted | Notes |
|---------|----------|-------|
| Bash(sudo:*) | 1x | Superuser execution — never auto-allow |

---

## Unknown — needs research

| Command | Prompted |
|---------|----------|
| Bash(someobscuretool:*) | 2x |

---

## No action needed

[List any commands that appeared in log but are already in settings.json allow list]

---

*To apply suggestions: copy the JSON lines above into the `allow` array in ~/.claude/settings.json. Restart Claude Code for changes to take effect. This report does not modify any files.*
```

Keep the report tight. Prioritize by frequency — highest-prompted commands first. If nothing needs adding, say so plainly.

---

## STEP 5 — SAVE REPORT

Write the report to `~/.claude/logs/permission-audit-[YYYY-MM-DD].md`.

Tell the user where the report was saved and remind them: nothing has been changed in their settings. They decide what to apply.
