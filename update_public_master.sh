#!/bin/bash


##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
## This script requires that script init_enteprise.sh has been run.
##
## This script updates branch "public_master" with latest changes in "master" which
## apply only to public content.
##
## Branch "public_master" can then merged fast-forward only into branch "master" of
## repository SonarSource/sonarqube.
##
##
##############################################################################################

set -euo pipefail

# TRASH
#CHILD_OF_LATEST_MASTER_SHA1="$(git log --format=%H ${LATEST_MASTER_SHA1}..master | tail -1)"

function info() {
  local MESSAGE="$1"
  echo
  echo "[INFO] ${MESSAGE}"
}

function error() {
  local MESSAGE="$1"
  echo 
  echo "[ERROR] ${MESSAGE}"
}

function pause() {
  echo "pause..."
  read
}

function refresh_branch() {
  local BRANCH="$1"
  local NEW_HEAD="$2"

 info "refresh ${BRANCH} to ${NEW_HEAD}"
  if [ -n "$(git branch --list "${BRANCH}")" ]; then
    git branch -D "${BRANCH}"
  fi
  git checkout -b "${BRANCH}" "${NEW_HEAD}"
}

function most_recent_tag_matching_pattern_in_branch() {
  local BRANCH="$1"
  local START_WITH_PATTERN="$2"

  # grep on PATTERN with heading space to avoid matching tag containing searched pattern
  # (and because tags are always prefixed by space in git log's output)
  IFS=',' read -r -a REFERENCES <<< $(git log --pretty="%D" "${BRANCH}" | grep "tag:" | grep " $START_WITH_PATTERN" | head -1)

  for REFERENCE in "${REFERENCES[@]}"; do
    # element might contain: "HEAD -> master, tag: tag_master_b73a4be295c4a0730613dcf29c12eb74e567a4eb, new_commits"
    if [ -z "${REFERENCE##*tag:*}" ]; then
      tags=(${REFERENCE})
      for tag in ${tags[*]}; do
        # multiple tags may match the pattern, but they're all as recent as the other, so take any of them
        if [ -z "${tag##$START_WITH_PATTERN*}" ]; then
          echo "$tag"
          return
        fi
      done
    fi
  done
}


# read info from public_master
info "read info from public_master"
LATEST_MASTER_PUBLIC_TAG="$(most_recent_tag_matching_pattern_in_branch "public_master" "tag_public_master_")"
echo "LATEST_MASTER_PUBLIC_TAG=$LATEST_MASTER_PUBLIC_TAG"
PUBLIC_MASTER_HEAD=$(git log -1 --pretty=tformat:%H "public_master")
echo "PUBLIC_MASTER_HEAD=$PUBLIC_MASTER_HEAD"

if [ "$(git log -1 --pretty="%D" "public_master" | grep "${LATEST_MASTER_PUBLIC_TAG}")" = "" ]; then
  error "latest tag_public_master_* tag is not on public_master head. Previous run of synchonization script left an inconsistent state"
  exit 1
fi

pause
info "read info from master and update it"
# update master
git checkout "master"
MASTER_HEAD=$(git log -1 --pretty=tformat:%H "master")
echo "MASTER_HEAD=$MASTER_HEAD"
LATEST_MASTER_TAG="$(most_recent_tag_matching_pattern_in_branch "master" "tag_master_")"
echo "LATEST_MASTER_TAG=$LATEST_MASTER_TAG"
LATEST_MASTER_SHA1="${LATEST_MASTER_TAG#tag_master_}"
echo "LATEST_MASTER_SHA1=$LATEST_MASTER_SHA1"

# git pull
if [ "$LATEST_MASTER_SHA1" = "$MASTER_HEAD" ]; then
  info "no new commit to merge"
  exit 0
fi

# (re)create master_work
refresh_branch "master_work" "master"

pause
# remove private repo data since LATEST_MASTER_TAG
info "deleting private data from public_master_work"
git filter-branch -f --prune-empty --index-filter 'git rm --cached --ignore-unmatch private/ -r' ${LATEST_MASTER_SHA1}..HEAD

pause
# (re)create public_master_work from public_master
refresh_branch "public_master_work" "public_master"

pause
# update public_master_work from master
git checkout "public_master_work"
info "cherry-picking from master_work into public_master_work"
git cherry-pick --keep-redundant-commits --allow-empty --strategy=recursive -X ours ${LATEST_MASTER_SHA1}..master_work

pause
info "clear any empty commit"
git filter-branch -f --prune-empty ${LATEST_MASTER_PUBLIC_TAG}..HEAD

pause
# merge public_master_work into public_master (ff-only for safety)
info "update public_master"
git checkout "public_master"
git merge --ff-only "public_master_work"

# create tags
info "create tags"
git tag "tag_public_master_${MASTER_HEAD}" "public_master"
git tag "tag_master_${MASTER_HEAD}" "master"
