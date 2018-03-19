#!/bin/bash


##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
##
## This script takes one argument: the name of the branch to recover (eg. feature/sl/foo).
##
## This script intends to recover a branch created in repository SonarSource/sonar-core-plugins
## and modifying its commits to thay they apply on SonarSource/sonar-enterprise master.
##
## If a branch in SonarSource/sonarqube has the same name as the branch in sonar-core-plugins
## then the content of both branches will be merged into the branch of sonar-enterprise.
## Commits of the branch in sonar-core-plugins are applied on top of those of the branch
## in sonarqube.
##
##############################################################################################

set -euo pipefail

REMOTE_CORE_PLUGINS="core-plugins"
REMOTE_SQ="sq"

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

function recover_core_plugin_branch() {
  BRANCH_NAME="$1"

  echo "Recovering branch core-plugins $BRANCH_NAME (and merge into SQ branch with same name if exists)..."
  pause

  local WORK_BRANCH_NAME="${BRANCH_NAME}_work"
  info "create branch ${WORK_BRANCH_NAME}"

  refresh_branch "${WORK_BRANCH_NAME}" "${REMOTE_CORE_PLUGINS}/${BRANCH_NAME}"

  local MASTER_COMMON_ANCESTOR_SHA1="$(git merge-base "master" "${REMOTE_CORE_PLUGINS}/master")"
  local BRANCH_COMMON_ANCESTOR_SHA1="$(git merge-base "${WORK_BRANCH_NAME}" "${REMOTE_CORE_PLUGINS}/master")"
  echo "MASTER_COMMON_ANCESTOR_SHA1=$MASTER_COMMON_ANCESTOR_SHA1"
  echo "BRANCH_COMMON_ANCESTOR_SHA1=$BRANCH_COMMON_ANCESTOR_SHA1"

  if [ "${BRANCH_COMMON_ANCESTOR_SHA1}" != "${MASTER_COMMON_ANCESTOR_SHA1}" ]; then
    error "core-plugins branch ${BRANCH_NAME} has not been rebased on ${REMOTE_CORE_PLUGINS}/master. Hit enter to attempt rebase, CTRL+C to stop"
    read
  fi

  # if rebase finds conflicts, script will stop
  git rebase "${REMOTE_CORE_PLUGINS}/master"

  info "moving files to private dir in new commits in ${WORK_BRANCH_NAME}"
  local MOVE_CMD="mkdir -p private \
&& mv sonar-branch-plugin/ sonar-billing-plugin/ sonar-developer-plugin/ sonar-governance-plugin/ sonar-ha-plugin/ private/ \
&& mv it-billing/ it-branch/ it-developer/ it-governance/ it-ha/ private/ \
&& mv build.gradle .gitignore settings.gradle Jenkinsfile private/ \
&& rm gradlew gradlew.bat .travis.yml travis.sh README.md gradle/ -r"

  local PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1="$(git log -1 --pretty=tformat:%H "${MASTER_COMMON_ANCESTOR_SHA1}~1")"
  echo "PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1=$PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1"
  git filter-branch -f --tree-filter "${MOVE_CMD}" -- ${PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1}..HEAD

  local NEW_MASTER_COMMON_ANCESTOR_SHA1="$(git log --format=%H ${PARENT_OF_MASTER_COMMON_ANCESTOR_SHA1}..HEAD | tail -1)"
  echo "NEW_MASTER_COMMON_ANCESTOR_SHA1=$NEW_MASTER_COMMON_ANCESTOR_SHA1"

  if [ "$(git branch -a | grep "${REMOTE_SQ}/${BRANCH_NAME}" || true)" != "" ]; then
    info "create branch ${BRANCH_NAME} from ${REMOTE_SQ}/${BRANCH_NAME}, rebase it on master and add new commits to it"
    refresh_branch "${BRANCH_NAME}" "${REMOTE_SQ}/${BRANCH_NAME}"
    git rebase master
  else
    info "create branch ${BRANCH_NAME} from master and add new commits to it"
    refresh_branch "${BRANCH_NAME}" "master"
  fi

  git cherry-pick --keep-redundant-commits --allow-empty --strategy=recursive -X ours ${NEW_MASTER_COMMON_ANCESTOR_SHA1}..${WORK_BRANCH_NAME}
}

# just to be sure on which branch we currently are
git checkout master

for i in $(git branch --all | grep core-plugins | grep -v dogfood | grep -v master | grep -v branch-7.0 | grep -v feature/eh/GOV-324 | grep -v feature/jl/fix_billing_qa | cut -c 24-300); do
  recover_core_plugin_branch "$i"
done

info "done"
