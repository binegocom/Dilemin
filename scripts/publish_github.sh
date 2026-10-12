#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v gh >/dev/null || { echo 'Install GitHub CLI: brew install gh' >&2; exit 1; }
gh auth status
gh auth setup-git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init -b main
fi
REPO='binegocom/Dilemin'
gh repo view "$REPO" --json nameWithOwner,visibility --jq '.nameWithOwner + " (" + .visibility + ")"'
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/$REPO.git"
fi
url="$(git remote get-url origin)"
case "$url" in
  "https://github.com/$REPO.git"|"git@github.com:$REPO.git") ;;
  *) echo "Unexpected remote: $url" >&2; exit 1 ;;
esac
# Only reconcile the known, README-only initial repository automatically.
git add -A
if ! git diff --cached --quiet; then
  git commit -m 'feat: Dılêmın core screens, safety and radar animation engines'
fi
if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
  git fetch origin main
  remote_files="$(git ls-tree -r --name-only FETCH_HEAD)"
  if [[ "$remote_files" != "README.md" ]]; then
    echo 'The remote repository contains application files. Refusing an automatic merge.' >&2
    echo 'Inspect git fetch origin main and merge your changes manually.' >&2
    exit 1
  fi
  git merge --allow-unrelated-histories -s ours FETCH_HEAD -m 'chore: integrate GitHub repository initialization'
fi
git push -u origin HEAD:main
printf 'Source published: https://github.com/%s\n' "$REPO"
