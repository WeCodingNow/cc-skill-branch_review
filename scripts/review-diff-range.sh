#!/usr/bin/env bash
#
# review-diff-range.sh — resolves the base branch for a branch review and
# prints the diff range against it.
#
# Where git-spice tracks the repository it holds each branch's declared
# base — the branch it is stacked on — and that answer is preferred: a
# stacked feature branch sits on another feature branch far more often
# than on a long-lived integration branch. A review branch is itself
# untracked, so the lookup walks to the nearest tracked branch that is an
# ancestor of HEAD and takes that branch's downstack base.
#
# Without git-spice, the base is the first of dev, main, master that
# exists, matching the worktree → dev → main convention (see global
# CLAUDE.md's git-commits rule and the feature-branching skill).
set -euo pipefail

branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "error: not on a branch (detached HEAD?)" >&2
  exit 1
fi

base=""
base_source=""

spice_json=""
if command -v git-spice >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  spice_json="$(git-spice log short --all --json --no-prompt 2>/dev/null || true)"
fi

if [ -n "$spice_json" ]; then
  # name<TAB>base for every tracked branch that declares a downstack base;
  # trunk itself declares none and drops out here.
  tracked="$(jq -r 'select(.down.name != null) | "\(.name)\t\(.down.name)"' \
    <<<"$spice_json" 2>/dev/null || true)"

  best_dist=""
  best_name=""
  best_down=""
  while IFS=$'\t' read -r name down; do
    [ -n "$name" ] && [ -n "$down" ] || continue
    git rev-parse --verify --quiet "refs/heads/$name" >/dev/null || continue
    git rev-parse --verify --quiet "refs/heads/$down" >/dev/null || continue
    # Only a branch HEAD already contains can describe what HEAD is built on.
    git merge-base --is-ancestor "$name" HEAD || continue

    if [ "$name" = "$branch" ]; then
      # HEAD's own branch is tracked: its base is the answer outright, and
      # -1 keeps it ahead of any branch it shares a tip with.
      dist=-1
    else
      dist="$(git rev-list --count "$name..HEAD")"
    fi

    if [ -z "$best_dist" ] || [ "$dist" -lt "$best_dist" ]; then
      best_dist="$dist"
      best_name="$name"
      best_down="$down"
    fi
  done <<<"$tracked"

  if [ -n "$best_down" ]; then
    base="$best_down"
    base_source="git-spice (downstack of $best_name)"
  fi
fi

if [ -z "$base" ]; then
  for candidate in dev main master; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      base="$candidate"
      base_source="name preference dev > main > master"
      break
    fi
  done
fi

if [ -z "$base" ]; then
  echo "error: no base branch found (git-spice knows none; dev/main/master absent)" >&2
  exit 1
fi

if [ "$base" = "$branch" ]; then
  echo "error: current branch ($branch) is the base branch itself" >&2
  exit 1
fi

echo "branch=$branch"
echo "base=$base"
echo "base_source=$base_source"
echo
echo "--- commits ($base..$branch) ---"
git log --oneline "$base..$branch"
echo
echo "--- diffstat ($base...$branch) ---"
git diff --stat "$base...$branch"
