#!/bin/bash

set -euo pipefail

# TRASH
#CHILD_OF_LATEST_MASTER_SHA1="$(git log --format=%H ${LATEST_MASTER_SHA1}..master | tail -1)"

function info {
  echo
  echo "#### $1"
}

function pause {
  echo "pause..."
  read
}

function refresh_branch {
  local BRANCH="$1"
  local NEW_HEAD="$2"

 info "refresh ${BRANCH} to {$NEW_HEAD}"
  if [ -n "$(git branch --list "${BRANCH}")" ]; then
    git branch -D ${BRANCH}
  fi
  git checkout -b ${BRANCH} ${NEW_HEAD}
}

function most_recent_tag_matching {
  local BRANCH="$1"
  local PATTERN="$2"

  g log --simplify-by-decoration --tags -l 10 --pretty="%D" | grep "tag:"
}


# update master
git checkout master
# git pull
MASTER_HEAD=$(git log -1 --pretty=tformat:%H)
echo "MASTER_HEAD=$MASTER_HEAD"
LATEST_MASTER_TAG="$(git tag -l "master_*" --merged master)"
echo "LATEST_MASTER_TAG=$LATEST_MASTER_TAG"
LATEST_MASTER_SHA1="${LATEST_MASTER_TAG#master_}"
echo "LATEST_MASTER_SHA1=$LATEST_MASTER_SHA1"

if [ "$LATEST_MASTER_SHA1" = "$MASTER_HEAD" ]; then
  info "no new commit to merge"
  exit 0
fi

# read info from public_master
LATEST_MASTER_PUBLIC_TAG="$(git tag -l "public_master_*" --merged public_master)"
echo "LATEST_MASTER_PUBLIC_TAG=$LATEST_MASTER_PUBLIC_TAG"

# (re)create master_work
refresh_branch master_work master

pause
# remove private repo data since LATEST_MASTER_TAG
info "deleting private data from public_master_work"
git filter-branch -f --prune-empty --index-filter 'git rm --cached --ignore-unmatch private/ -r' ${LATEST_MASTER_SHA1}..HEAD

pause

# (re)create public_master_work from public_master
refresh_branch public_master_work public_master

pause

# update public_master_work from master
git checkout public_master_work
info "cherry-picking from master_work into public_master_work"
git cherry-pick --keep-redundant-commits --allow-empty --strategy=recursive -X ours ${LATEST_MASTER_SHA1}..master_work

pause

info "clear any empty commit"
git filter-branch -f --prune-empty ${LATEST_MASTER_PUBLIC_TAG}..HEAD

pause

# merge public_master_work into public_master (ff-only for safety)
info "update public_master"
git checkout public_master
git merge --ff-only public_master_work

# create tags
info "create tags"
git tag "public_master_${MASTER_HEAD}" public_master
git tag "master_${MASTER_HEAD}" master
