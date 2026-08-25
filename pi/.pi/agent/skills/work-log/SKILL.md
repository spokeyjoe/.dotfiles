---
name: work-log
description: Work-log generation for a completed development task or end-of-session progress, grounded in session context, repository changes, plans, and Git history.
---

# Work Log

Produce an evidence-backed record of the work unit and add it to the repository's work-log index.

## 1. Establish scope and conventions

1. Find the repository root and read any repository instructions.
2. Treat the current task or session as the primary scope. Use Git to corroborate it: inspect status, the current branch, relevant diffs, and recent commits with full bodies. If the work spans a branch, compare it with the appropriate merge base rather than assuming `HEAD~1`.
3. Inspect existing `docs/work-logs/INDEX.md` and recent work logs for repository conventions. Search plan or design documents using terms from the scoped work; read only relevant matches.
4. Include related uncommitted changes and untracked files. Exclude nearby commits or changes that belong to another work unit.

This step is complete when the work-unit boundary is clear and every intended claim has a source in the session, repository, plan documents, or Git history.

## 2. Write the log

Follow established repository conventions. If none exist, create:

`docs/work-logs/YYYY-MM-DD-topic-name.md`

Use the local date and a short kebab-case topic. Avoid overwriting an existing log; choose a more specific topic or add a numeric suffix.

Use this fallback structure:

```markdown
# Work Log: [Descriptive title]

**Date:** YYYY-MM-DD
**Author:** [Author or "Not recorded"]
**Branch:** `branch-name`
**Status:** Completed | In Progress
**Commits:** [Related hashes and subjects, or "Uncommitted"]

## Objective
[Outcome the work aimed to achieve]

## Background
[Only context needed to understand the work]

## Changes Implemented
[Changes grouped by subsystem or theme]

## Technical Decisions
[Decisions and evidenced rationale, or "No explicit decisions recorded"]

## Verification
[Checks actually run and their outcomes, or "Not recorded"]

## Known Issues and Future Work
[Known remaining work or limitations, or "None recorded"]

## References
[Relative links to relevant plans, code, issues, or discussions]
```

Derive the author from explicit session context, repository convention, or Git configuration, in that order. Mark the status `Completed` only when completion is established by the task context; otherwise use `In Progress`. Include only related commits. Link hashes when the repository remote yields a reliable web URL; otherwise format them as code.

Describe outcomes before implementation details. Record decisions, verification, limitations, and references only when supported by evidence; use the fallback text instead of inference.

This step is complete when all scoped changes are represented, unrelated work is absent, and every factual statement is evidence-backed.

## 3. Update the index

Preserve the existing index format and ordering. If no index exists, create `docs/work-logs/INDEX.md` with:

```markdown
# Work Logs

| Date | File | Commit | Description |
|------|------|--------|-------------|
| YYYY-MM-DD | [filename.md](filename.md) | `hash` | One-sentence outcome |
```

Add exactly one entry for the log. Use a relative file link, list only related commit hashes (or `Uncommitted`), and describe the achieved outcome in one concise sentence. Keep code-level names out of the description unless they are essential to understanding the outcome.

This step is complete when the log has one non-duplicate index entry and every added relative link resolves.

## 4. Validate and report

Review the new log and index diff. Check dates, status, commit hashes, changed-file coverage, Markdown structure, and relative links. Leave the files uncommitted unless the user asked for a commit.

Report the paths created or updated and any scope, verification, author, or commit information that could not be established.

This step is complete when both files are internally consistent and all uncertainty is explicit.
