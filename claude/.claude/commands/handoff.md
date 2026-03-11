# Handoff Command

Document the current session's work progress and context for future continuation.

## Instructions

Create or update the HANDOFF.md file in the project root using the template below.

### Template

```markdown
---
date: [Current date and time with timezone in ISO format]
git_commit: [Current commit hash from `git rev-parse HEAD`]
branch: [Current branch name]
status: [complete | in-progress | blocked]
last_updated: [Current date in YYYY-MM-DD format]
---

# Handoff: {very concise description of session focus}

## Task(s)
{Description of the task(s) worked on, with status of each: completed, in-progress, or planned/discussed. If working from an implementation plan, call out which phase you are on and reference the plan document.}

## Critical References
{2-3 most important spec docs, architecture decisions, or design docs that must be followed. File paths only. Leave blank if none.}

## Recent Changes
{Describe changes made to the codebase in file:line syntax.}

## Build/Test Status
{Current state of builds and tests. Note any failures or regressions.}

## Learnings
{Important discoveries: patterns, root causes of bugs, gotchas, or other context someone picking up this work should know. Include explicit file paths where relevant.}

## Artifacts
{Exhaustive list of artifacts produced or updated as file paths and/or file:line references — feature docs, implementation plans, etc. that should be read to resume work.}

## Action Items & Next Steps
{Ordered list of what the next session should do, based on task statuses above.}

## Other Notes
{Anything else useful: relevant codebase sections, related documents, blockers, open questions, or decisions still pending.}
```

## Process

1. Review the conversation history to identify all work done
2. Run `git status`, `git log`, and `git diff` to capture current state
3. Note any failing tests or build issues
4. Document decisions made, trade-offs considered, and lessons learned
5. Write everything to HANDOFF.md using the template above

The goal is to provide enough context so that work can be seamlessly resumed in a new session — by you or another agent.
