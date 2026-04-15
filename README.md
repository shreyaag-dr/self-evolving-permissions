# self-evolving-permissions

A Claude Code tool that logs every permission prompt and blocked command, then periodically suggests which ones are safe to add to your `settings.json` — so your AI agent stops getting stuck without you having to guess what to allow.

**Human-in-the-loop by design.** This tool never modifies your settings automatically. It analyzes, classifies, and proposes. You decide what gets added.

---

## The problem

Claude Code's permission system is set once and forgotten. Over time:

- Unattended jobs stall at 2 AM waiting for you to approve a `jq` command
- You add permissions reactively, one at a time, with no sense of what else might be missing
- Over-permitting is risky; under-permitting kills autonomous workflows

There's no feedback loop between what Claude *tries* to do and what your config *allows*.

## How it works

**1. Capture** — Two hooks tap into Claude Code's `PermissionRequest` and `PermissionDenied` events and append structured entries to `~/.claude/logs/permission-prompts.jsonl`. Passive, zero overhead.

**2. Analyze** — Run `/permission-audit` in any Claude Code session. It reads your log, compares against a curated safety registry, and classifies each blocked command by risk level and persona fit.

**3. Propose** — You get a markdown report with a copy-pasteable diff for `settings.json`. Nothing is applied until you say so.

---

## Install

```bash
git clone https://github.com/shreyaagrawal/self-evolving-permissions
cd self-evolving-permissions
./install.sh
```

Start a new Claude Code session after installing. Hooks apply to new sessions only.

## Usage

Use Claude Code normally. The logger runs silently in the background.

When you want an audit (recommended: weekly or monthly):

```
/permission-audit
```

Review the report. Copy the suggested lines into `~/.claude/settings.json`. Done.

## Who this is for

**Developers** — Getting interrupted mid-flow by `npm`, `docker`, `jq`, or `curl` prompts. Want speed without opening up everything.

**Product managers / hybrid users** — Running overnight autonomous jobs that stall on a permission prompt. Need reliability without granting blanket access.

**Enterprise / team leads** — Want a principled, auditable baseline for a shared `settings.json` committed to a dotfiles repo.

---

## Prior art

[rohitg00/pro-workflow](https://github.com/rohitg00/pro-workflow) (1.9k stars) has a `/permission-tuner` skill that does something similar inside a larger workflow framework. This project is a standalone, schedulable version with a human-approval step and multi-persona registry.

---

## Contributing

This is a reference implementation. It is not actively maintained as a community project.

Fork it, adapt it, use it. Open an issue if you find a bug or want to suggest a registry addition — those I'll review on a best-effort basis.

PRs to the core permission logic are not accepted. The risk of malicious contributions to a tool that modifies security settings is too high for a project at this scale.

---

## License

MIT
