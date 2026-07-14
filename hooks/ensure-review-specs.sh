#!/usr/bin/env bash
#
# ensure-review-specs.sh — Claude Code `Stop` hook for the branch-review skill.
#
# Wired via branch-review's SKILL.md frontmatter (hooks.Stop): once
# `/branch-review` is explicitly run (branch-review is
# disable-model-invocation), this hook stays registered for every Stop event
# for the rest of the session — including later, unrelated turns after the
# review is done and another skill has moved the session to a non-review
# branch. The branch check below guards against false-positives from that.
#
# If the repo has no .spec/review/ by the time Claude finishes responding
# *while on a review/* branch*, block once and ask it to write the review
# findings there first — backing up the output-format convention documented
# in the skill.
set -euo pipefail

input="$(cat)"

# Loop guard: if this Stop is itself the continuation caused by a prior Stop-hook
# block, do not block again — let the agent finish. This makes the hook fire at
# most once per turn and can never trap the session in a stop -> continue loop.
if [ "$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null || echo false)" = "true" ]; then
  exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"
if [ -z "$cwd" ] || ! git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Only review/* branches are ever expected to have .spec/review/ — on any
# other branch a missing one is normal, not something to nudge about.
branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
if [[ "$branch" != review/* ]]; then
  exit 0
fi

# Already recorded on this branch — nothing to nudge.
if [ -d "$cwd/.spec/review" ]; then
  exit 0
fi

# stdout must contain only the JSON object. For Stop, `decision: "block"` feeds
# `reason` back to the model and continues the turn so it can act on it; the
# loop guard above ensures this happens at most once.
jq -nc '{
  decision: "block",
  reason: "No .spec/review/ exists yet in this repo. Per the branch-review skill, the review findings must be written directly under .spec/review/ (00-overview.md, 01-bugs.md, 02-refactoring.md, 03-security.md, 04-style-docs.md) plus .spec/review/TODO.md — one branch = one review, no numbered subdirectory. Write them before finishing. If no review was actually requested or performed this turn, say so briefly and finish; this check will not fire again."
}'
