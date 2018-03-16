#!/bin/bash

##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
##
## This script set the initial tags on branches "master" and "public_master" on which
## script update_public_master.sh will rely on to work.
##
## This script will detect and fail if tags are already present.
##
##############################################################################################


set -euo pipefail

function info() {
  local MESSAGE="$1"
  echo "[INFO] ${MESSAGE}"
}

function error() {
  local MESSAGE="$1"
  echo "[ERROR] ${MESSAGE}"
}

if [ "$(git log --pretty="%D" "master" | grep " tag_master")" != "" ]; then
  error "tag already initialized on branch master"
  exit 1
fi
if [ "$(git log --pretty="%D" "public_master" | grep " tag_public_master")" != "" ]; then
  error "tag already initialized on branch public_master"
  exit 1
fi

# in branch master_public, created from SonarSource/sonarqube master
PUBLIC_SQ_HEAD_SHA1="fe6fcaba75e7ca02678a4ce0dff601b448a2fd7a"
# in branch master
SQ_MERGE_COMMIT_SHA1="50bdba5ed6693aec1be2e1b04a63c1b0c1ef49fd"

# create initial tag commits
info "create initial tags"
git tag "tag_public_master_${SQ_MERGE_COMMIT_SHA1}" ${PUBLIC_SQ_HEAD_SHA1}
git tag "tag_master_${SQ_MERGE_COMMIT_SHA1}" ${SQ_MERGE_COMMIT_SHA1}

