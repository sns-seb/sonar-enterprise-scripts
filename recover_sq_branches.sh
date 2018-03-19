#!/bin/bash


##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
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

REMOTE_SQ="sq"

for BRANCH_NAME in $(git branch --all | grep "remotes/${REMOTE_SQ}" | grep -v "branch-" | grep -v "master" | grep -v "dogfood" | grep -v "4.5.5" | grep -v "daniel" | grep -v "6.7" | grep -v "fast-es-tests" | grep -v "graphql" | grep -v "feature/dm/sq56" | grep -v "feature/eh/SONAR-10310" | grep -v "feature/jl/SONAR-10248/secondary_emails_sync"  | grep -v "feature/sb/test-artifacts" | cut -c 14-300); do

  if [ "$(git branch | grep "${BRANCH_NAME}" || true)" != "" ]; then
    info "branch ${BRANCH_NAME} already merged by recovering core-plugins branch with same name"
  else
    git checkout -b "${BRANCH_NAME}" "${REMOTE_SQ}/${BRANCH_NAME}"
    git branch --unset-upstream
    info "Ensure branch ${BRANCH_NAME} is up to date with ${REMOTE_SQ}/master..."
    pause
    git rebase "${REMOTE_SQ}/master"
  
    info "rebasing ${BRANCH_NAME} on master..."
    pause
    git rebase "master"
  fi
  
done

exit 0

