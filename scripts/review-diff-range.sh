#!/usr/bin/env bash
#
# review-diff-range.sh — resolves the base branch for a branch review and
# prints the diff range against it.
#
# Base branch preference: dev > main > master, matching the worktree → dev
# → main convention (see global CLAUDE.md's git-commits rule and the
# feature-branching skill) — dev is the shared integration branch, so it's
# almost always the right diff target; main/master are the fallback for
# repos with no dev branch at all.
set -euo pipefail

branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "error: not on a branch (detached HEAD?)" >&2
  exit 1
fi

base=""
for candidate in dev main master; do
  if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
    base="$candidate"
    break
  fi
done

if [ -z "$base" ]; then
  echo "error: none of dev/main/master exist in this repo" >&2
  exit 1
fi

if [ "$base" = "$branch" ]; then
  echo "error: current branch ($branch) is the base branch itself" >&2
  exit 1
fi

echo "branch=$branch"
echo "base=$base"
echo
echo "--- commits ($base..$branch) ---"
git log --oneline "$base..$branch"
echo
echo "--- diffstat ($base...$branch) ---"
git diff --stat "$base...$branch"
