#!/bin/bash


##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonar-enterprise.
##
## This script commits work of init_enteprise.sh and sync_public_master.sh by pushing branch
## public_master and tags used by sync_public_master.sh to remote.
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

REMOTE="origin"

info "Pushing public_master..."
git checkout "public_master"
#git push

info "Pushing tags to ${REMOTE}..."
TMP_EXISTING_TAGS_FILE=$(mktemp)
git ls-remote --tags "${REMOTE}" | cut -f 2 | cut -c 11-300 | grep "^tag_public_master_\|^tag_master_public_" > ${TMP_EXISTING_TAGS_FILE} || true

for tag in $(git tag --list "tag_public_master_*" "tag_master_*" | grep -v --file="${TMP_EXISTING_TAGS_FILE}"); do
  echo "committing tag $tag"
  #git push "${REMOTE}" "$tag"
done

info "done"
