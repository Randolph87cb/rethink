---
name: record-and-reflect-review
description: Record summarized AI conversation work, review recurring work patterns, and propose or maintain Codex skills from repeated workflows. Use when the user asks to record a thread, summarize recent AI work, review previous work, identify repeated task patterns, create a skill backlog, add a new skill from historical work, or optimize an existing skill based on past AI-assisted tasks.
---

# 记录以及反思回顾

## Purpose

Maintain a private, Git-synced memory of AI-assisted work. Record each thread as a concise Markdown summary, then periodically review records to find repeated workflows that should become new skills or improvements to existing skills.

## Default Policy

- Record summaries only. Do not save full conversation transcripts unless the user explicitly asks.
- Exclude secrets, tokens, private credentials, raw customer/company data, and unnecessary personal details.
- Keep records useful for future work: capture intent, decisions, changed files, commands, outcomes, reusable process notes, and follow-ups.
- Follow the active workspace's `AGENTS.md` or user rules before modifying files, skills, or Git state.
- When updating this skill or other skills, use the `skill-creator` guidance and validate the result.

## Repository Layout

Use this skill folder as the Git repository root:

```text
record-and-reflect-review/
├── SKILL.md
├── agents/openai.yaml
├── records/
│   └── YYYY/MM/*.md
├── skill-backlog.md
├── scripts/
│   ├── new_record.ps1
│   └── collect_records.ps1
└── references/
    └── record-template.md
```

## Recording A Thread

1. Build a summary from the current thread.
2. Read `references/record-template.md` when the structure is needed.
3. Use `scripts/new_record.ps1` to create the dated record file, or create the Markdown manually if the script is not suitable.
4. Update `skill-backlog.md` when the thread reveals a possible reusable skill or an improvement to an existing skill.
5. If this folder is a Git repository, run Git operations serially: `git status`, `git add`, `git commit`, then `git push`.

Suggested command pattern in PowerShell:

```powershell
$summary = @'
<completed Markdown summary>
'@
$summary | powershell -ExecutionPolicy Bypass -File .\scripts\new_record.ps1 -Title "short thread title"
```

## Reviewing History

When the user asks to review recent work, summarize history, or identify recurring workflows:

1. Use `scripts/collect_records.ps1` to list recent records and optionally include excerpts.
2. Read the relevant record files.
3. Group repeated work by trigger phrase, workflow, file type, toolchain, and failure pattern.
4. Treat a pattern as a skill candidate when it appears at least three times, is likely to recur, or caused avoidable friction.
5. Recommend one of:
   - create a new skill;
   - improve an existing skill;
   - add a script/reference/template to an existing skill;
   - keep only as a record because the pattern is not stable enough.

## Creating Or Improving Skills

Before changing a skill:

1. Explain the proposed change and get user confirmation if required by the active workspace rules.
2. Keep `SKILL.md` concise and move detailed examples into `references/`.
3. Add scripts only when a repeated operation benefits from deterministic execution.
4. Validate with the skill validator:

```powershell
python "C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py" "<skill-folder>"
```

## Syncing

Use Git as the sync mechanism between machines. Keep Git commands serial and use Chinese commit messages when the user or workspace rules require them.
