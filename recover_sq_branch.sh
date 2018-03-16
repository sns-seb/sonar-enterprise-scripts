#!/bin/bash


##############################################################################################
##
##
##############################################################################################

set -euo pipefail

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

BRANCH="$1"
REMOTE="$2"

echo "Recovering branch $BRANCH from remote $REMOTE..."
echo

# just to be sure on which branch we currently are
git checkout master

WORK_BRANCH_NAME="${BRANCH}_work"
info "create branch ${WORK_BRANCH_NAME}"
refresh_branch "${WORK_BRANCH_NAME}" "${REMOTE}/${BRANCH}"

MASTER_COMMON_ANCESTOR_SHA1="$(git merge-base "master" "${REMOTE}/master")"
BRANCH_COMMON_ANCESTOR_SHA1="$(git merge-base "${WORK_BRANCH_NAME}" "${REMOTE}/master")"
echo "MASTER_COMMON_ANCESTOR_SHA1=$MASTER_COMMON_ANCESTOR_SHA1"
echo "BRANCH_COMMON_ANCESTOR_SHA1=$BRANCH_COMMON_ANCESTOR_SHA1"

if [ "${BRANCH_COMMON_ANCESTOR_SHA1}" != "${MASTER_COMMON_ANCESTOR_SHA1}" ]; then
  error "branch ${BRANCH} has not been rebased on ${REMOTE}/master. Hit enter to attempt rebase, CTRL+C to stop"
  read
fi

git rebase "${REMOTE}/master"

info "If rebase failed, hit CTRL+C to stop and do rebase manually"
read

info "moving files to private dir in new commits in ${WORK_BRANCH_NAME}"
MOVE_CMD="mkdir -p private \
&& mv sonar-branch-plugin/ sonar-billing-plugin/ sonar-developer-plugin/ sonar-governance-plugin/ sonar-ha-plugin/ private/ \
&& mv it-billing/ it-branch/ it-developer/ it-governance/ it-ha/ private/ \
&& mv build.gradle .gitignore settings.gradle Jenkinsfile private/ \
&& rm gradlew gradlew.bat .travis.yml travis.sh README.md gradle/ -r"

PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1="$(git log -1 --pretty=tformat:%H "${MASTER_COMMON_ANCESTOR_SHA1}~1")"
echo "PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1=$PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1"
git filter-branch -f --tree-filter "${MOVE_CMD}" -- ${PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1}..HEAD

NEW_MASTER_COMMON_ANCESTOR_SHA1="$(git log --format=%H ${PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1}..HEAD | tail -1)"
echo "NEW_MASTER_COMMON_ANCESTOR_SHA1=$NEW_MASTER_COMMON_ANCESTOR_SHA1"

info "create branch ${BRANCH} from master and add new commits to it"
refresh_branch "${BRANCH}" "master"
git cherry-pick --keep-redundant-commits --allow-empty --strategy=recursive -X ours ${NEW_MASTER_COMMON_ANCESTOR_SHA1}..${WORK_BRANCH_NAME}

info "clear any empty commit"
git filter-branch -f --prune-empty master..HEAD


exit 0

SQ_COMMON_ANCESTOR_SUBJECT="$(git log -1 --format=%s "${SQ_COMMON_ANCESTOR_SHA1}")"

info "Base commit of branch ${BRANCH} with public_master is:"
echo "${SQ_COMMON_ANCESTOR_SHA1} - ${SQ_COMMON_ANCESTOR_SUBJECT}"

MASTER_COMMON_ANCESTOR="$(git log --format="%H --- %s" master | grep "${SQ_COMMON_ANCESTOR_SUBJECT}" | head -1 || true)"

info "Input matching commits for base commit in master (preselected=${MASTER_COMMON_ANCESTOR}), hit enter to use it) from list below (or not):"
git log --format="%H - %s" master | grep "${SQ_COMMON_ANCESTOR_SUBJECT}" || true
read i

if [ "${i}" != "" ]; then
  MASTER_COMMON_ANCESTOR_SHA1="${i}"
fi

if [ "$(git log -1 "${MASTER_COMMON_ANCESTOR_SHA1}")" = "" ]; then
  error "commit ${MASTER_COMMON_ANCESTOR_SHA1} not found"
  exit 1
fi


exit 0

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
