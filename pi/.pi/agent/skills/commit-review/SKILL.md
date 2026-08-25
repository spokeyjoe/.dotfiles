---
name: commit-review
description: Review a git commit message — use when the user asks to review or improve a commit message (HEAD or a named commit), or wants a final polish on a commit before pushing or opening a PR.
---

# Commit Message Review

Review a commit message as a senior engineer would, then hand back a ready-to-use
rewrite. Two anchors run through the whole review:

- **Ground truth** — the diff is the ground truth; the message is judged against
  the code, never against neighboring commits. Hold an absolute bar: the repo log
  is casual and carries no authority. The one convention honored is the
  commit-style section of `CLAUDE.md`.
- **Causal chain** — a good message carries a complete causal chain: *mechanism*
  (why it breaks: type mismatch, off-by-one, stale cache) → *consequence* (what
  that does: hang, crash, wrong value) → *change* (what was done and the key
  design choices).

Default target is `HEAD`; if the user names a ref, SHA, or range, review that.

## Steps

1. **Gather ground truth.** Run `git show <ref> --format=full` for the message
   and full diff, and read the commit-style section of `CLAUDE.md`. Done when you
   hold the message, the complete diff, and the declared style rules.
2. **Verify.** Trace every factual claim in the message to a hunk in the diff,
   and grep the tree for every identifier the message names (functions, params,
   callers) to catch stale names and unstated scope risks — e.g. other callers of
   a changed signature the message should have ruled out. Done when every claim
   and every identifier is either confirmed or flagged as an issue.
3. **Assess.** Apply every axis of the checklist below, citing the offending
   line for each issue found.
4. **Present** the review in the output format below.

## Checklist

- **Subject** — matches the `CLAUDE.md` subject format and length limit (72
  chars unless stated otherwise); imperative mood; leads with the effect or
  behavior rather than restating the diff mechanically; identifiers are the real
  ones from the code, verbatim.
- **Body** — opens with motivation (the bug, current behavior, or need); carries
  the full causal chain, with the mechanism named and the consequence spelled
  out rather than left to inference; later paragraphs give the change and its
  design choices; written for a reader who knows the codebase but not this
  change; follows the `CLAUDE.md` body rules.
- **Honesty** — every claim matches the diff; scope claims stay within what the
  diff shows; questions a reviewer would ask (other callers, behavior changes)
  are pre-empted or noted.
- **Prose** — grammar, subject-verb agreement, present tense, concise
  paragraphs.

## Output

1. **What's already good** — 1–3 genuine points, anchoring what the rewrite
   keeps.
2. **Where it can be sharper** — numbered issues, each citing the offending line
   with the fix and the reason; substance (causal chain, honesty) ranked above
   grammar.
3. **Suggested rewrite** — a complete, ready-to-use message in a code block, in
   the `CLAUDE.md` style, followed by one sentence on any judgment call the user
   still owns (e.g. effect-first vs mechanism-first subject).

Deliver the rewrite as text only; amend the commit only when the user explicitly
asks, and confirm the final message with them first.
