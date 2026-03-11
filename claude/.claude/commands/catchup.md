# Catchup Command

Read the HANDOFF.md file and prepare to continue work from the previous session.

## Instructions

1. **Read HANDOFF.md**: Load the handoff document from the project root

2. **Parse Context**: Extract and internalize:
   - **Frontmatter**: branch, commit hash, status, date — check how stale the handoff is
   - **Task(s)**: what was being worked on and the status of each (completed, in-progress, planned)
   - **Critical References**: read any referenced spec/design docs (2-3 files max)
   - **Recent Changes**: files modified last session
   - **Learnings**: gotchas, patterns, root causes discovered — avoid re-learning these
   - **Artifacts**: plans, docs, or other files produced — skim key ones for context
   - **Action Items & Next Steps**: the prioritized work queue
   - **Other Notes**: blockers, open questions, pending decisions

3. **Verify Current State**:
   - Run `git status` — confirm branch matches handoff, check for uncommitted changes
   - Run `git log --oneline -5` — see if new commits landed since the handoff
   - If the handoff commit differs from HEAD, run `git log --oneline <handoff_commit>..HEAD` to understand what changed
   - Quickly verify build/test status if the handoff flagged issues

4. **Read Artifacts**: If the handoff references implementation plans, design docs, or research docs, read them now so you have full context before proceeding.

5. **Summarize for User**: Present a concise summary:
   - Where we left off (branch, task status, last commit)
   - What diverged since (new commits, uncommitted changes)
   - Key learnings to carry forward
   - The next steps from the handoff

6. **Ask for Direction**: Confirm with the user which task to resume or if priorities have changed.

## Goal

Seamlessly resume work from the previous session with full context, minimizing ramp-up time.
