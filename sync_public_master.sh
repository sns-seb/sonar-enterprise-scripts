#!/bin/bash


##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
## This script requires that script init_enteprise.sh has been run prior to being called.
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

info() {
  local MESSAGE="$1"
  echo "[INFO] ${MESSAGE}"
}

error() {
  local MESSAGE="$1"
  echo 
  echo "[ERROR] ${MESSAGE}"
}

pause() {
  echo "pause..."
  read
}

recreate_and_checkout() {
  local BRANCH="$1"
  local NEW_HEAD="$2"

  info "refresh ${BRANCH} to ${NEW_HEAD}"
  if [ "$(git branch --list "${BRANCH}")" ]; then
    git branch -D "${BRANCH}"
  fi
  git checkout -b "${BRANCH}" "${NEW_HEAD}"
}

can_fast_forward() {
  local from=$1
  local to=$2
  [ "$(git rev-list --max-count 1 "$from".."$to")" = "$to" ]
}

sha1() {
  git rev-parse "$1"
}

same_refs() {
  [ "$(sha1 "$1")" = "$(sha1 "$2")" ]
}

commit() {
  git log -n 1 --pretty="%h - %s (%an %cr)" "$1"
}

REF_TREE_ROOT="refs/public_sync"
REMOTE="origin"
SQ_REMOTE="sq"
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"

# so that we know where we are
git checkout "master"

info "Fetching ${SQ_REMOTE}/master ..."
git fetch --no-tags "${SQ_REMOTE}"
git reset --hard "${SQ_REMOTE}/master"

info "Fetching refs from ${REMOTE}..."
git fetch --no-tags "${REMOTE}" "+${REF_TREE_ROOT}/*:${REF_TREE_ROOT}/*"

info "Reading references..."
#LATEST_SYNC_DATE="$(git for-each-ref --count=1 --sort=-refname "$REF_TREE_ROOT/tags/**" --format='%(refname)' | cut -d/ -f3)"
LATEST_PUBLIC_MASTER_REF="${REF_TREE_ROOT}/latest/public_master"
LATEST_MASTER_REF="${REF_TREE_ROOT}/latest/master"

info "Latest sync merged \"$(commit ${LATEST_MASTER_REF})\" into branch public_master as \"$(commit ${LATEST_PUBLIC_MASTER_REF})\""

if ! same_refs "public_master" "${LATEST_PUBLIC_MASTER_REF}"; then
  error "Latest reference to public master ($(sha1 ${LATEST_PUBLIC_MASTER_REF})) is not HEAD of branch public_master. Previous run of synchonization script left an inconsistent state"
  exit 1
fi

if same_refs "master" "${LATEST_MASTER_REF}"; then
  info "no new commit to merge"
  exit 0
fi

# (re)create master_work
recreate_and_checkout "master_work" "master"

# remove private repo data since LATEST_MASTER_REF
info "deleting private data from master_work"
pause
git filter-branch -f --prune-empty --index-filter 'git rm --cached --ignore-unmatch private/ -r' ${LATEST_MASTER_REF}..HEAD

# (re)create public_master_work from public_master
recreate_and_checkout "public_master_work" "public_master"

# update public_master_work from master
info "cherry-picking from master_work into public_master_work"
pause
git cherry-pick ${LATEST_MASTER_REF}..master_work

# merge public_master_work into public_master (ff-only for safety)
info "update public_master"
pause
git checkout "public_master"
git merge --ff-only "public_master_work"

info "create refs"
git update-ref "${REF_TREE_ROOT}/tags/${TIMESTAMP}/master" "master"
git update-ref "${REF_TREE_ROOT}/tags/${TIMESTAMP}/public_master" "public_master"
git update-ref "${LATEST_MASTER_REF}" "master"
git update-ref "${LATEST_PUBLIC_MASTER_REF}" "public_master"

# log created references
git for-each-ref --count=2 --sort=-refname "${REF_TREE_ROOT}/tags"
git for-each-ref --count=1 --sort=-refname "${LATEST_MASTER_REF}"
git for-each-ref --count=1 --sort=-refname "${LATEST_PUBLIC_MASTER_REF}"

info "done"
