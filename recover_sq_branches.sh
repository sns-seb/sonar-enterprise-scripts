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

for BRANCH in $(git branch --all | grep "remotes/${REMOTE_SQ}" | grep -v "branch-" | grep -v "master" | grep -v "dogfood" | grep -v "4.5.5" | grep -v "daniel" | grep -v "6.7" | grep -v "fast-es-tests" | grep -v "graphql" | cut -c 14-300); do
  echo "$BRANCH"
  # TODO ignore branches which have already been merged by recover_core-plugins_branch.sh


done

exit 0

