#!/usr/bin/env bash
#
# ensure-review-specs.sh — Claude Code `Stop` hook for the branch-review skill.
#
# Wired via branch-review's SKILL.md frontmatter (hooks.Stop), so it only runs
# while that skill is active. Because branch-review is disable-model-invocation,
# "active" means only during an explicit `/branch-review` run.
#
# If the repo has no .spec/review/ by the time Claude finishes responding, block
# once and ask it to write the review findings there first — backing up the
# output-format convention documented in the skill.
#
# Absorbed from the former standalone cc-hook-review-specs project. Because it
# now only ever fires inside a branch-review session, it no longer needs to
# sniff which skill was invoked: the old tool_input field-name guessing and the
# code-review|security-review|... regex are gone.
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
