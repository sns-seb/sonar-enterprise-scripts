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

SQ_REMOTE="sq"

# in branch master_public, created from SonarSource/sonarqube master
PUBLIC_SQ_HEAD_SHA1="73e39a73e70b97ab0043cf5abc4eddcf68f2ce00"
# in branch master
SQ_MERGE_COMMIT_SHA1="b4eeaaa8b52bf9a51c2e4bf18436831ccb389146"

# to know where we are
git checkout master

# create "pulic_master" if doesn't exist yet
if [ "$(git branch --list "public_master")" = "" ]; then
  git checkout -b "public_master" "${PUBLIC_SQ_HEAD_SHA1}"
fi

if [ "$(git log --pretty="%D" "master" | grep " tag_master")" != "" ]; then
  error "tag already initialized on branch master"
  exit 1
fi
if [ "$(git log --pretty="%D" "public_master" | grep " tag_public_master")" != "" ]; then
  error "tag already initialized on branch public_master"
  exit 1
fi

# create initial tag commits
info "create initial tags"
git tag "tag_public_master_${SQ_MERGE_COMMIT_SHA1}" ${PUBLIC_SQ_HEAD_SHA1}
git tag "tag_master_${SQ_MERGE_COMMIT_SHA1}" ${SQ_MERGE_COMMIT_SHA1}

