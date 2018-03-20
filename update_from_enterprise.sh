#!/bin/bash

##############################################################################################
##
## This script is intended to be run on a clone of repository SonarSource/sonarqube.
##
##############################################################################################


set -euo pipefail

info() {
  local MESSAGE="$1"
  echo "[INFO] ${MESSAGE}"
}

ENTERPRISE_REPO="git@github.com:SonarSource/sonar-enterprise.git"

info "updating sonarqube master from sonar-enterprise public_master..."

if [ "$(git remote -v | grep "enterprise" || true)" = "" ]; then
  git remote add enterprise "${ENTERPRISE_REPO}"
fi

git fetch --no-tags "enterprise" "public_master" 

git checkout "master"
git merge --ff-only "enterprise/public_master"

info "done"
