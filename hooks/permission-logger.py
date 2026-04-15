#!/usr/bin/env python3
"""
permission-logger.py

Hooks into Claude Code's PermissionRequest and PermissionDenied events.
Appends a structured log entry to ~/.claude/logs/permission-prompts.jsonl
for every command that prompted the user or was silently denied.

This log is the input to the permission-audit skill.
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

    # Extract the actual command string for Bash calls
    command = tool_input.get("command", "") if tool_name == "Bash" else ""

    # For MCP tools, capture the tool identifier
    mcp_tool = tool_name if tool_name.startswith("mcp__") else ""

    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": event,
        "tool_name": tool_name,
        "command": command,
        "mcp_tool": mcp_tool,
        "tool_input": tool_input,
        "reason": data.get("reason", ""),
        "permission_mode": data.get("permission_mode", ""),
        "session_id": data.get("session_id", ""),
        "cwd": data.get("cwd", ""),
    }

    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    main()
