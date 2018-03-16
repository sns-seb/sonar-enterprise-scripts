#!/bin/bash

set -euo pipefail

# in branch master_public, created from SonarSource/sonarqube master
PUBLIC_SQ_HEAD_SHA1="fe6fcaba75e7ca02678a4ce0dff601b448a2fd7a"
# in branch master
SQ_MERGE_COMMIT_SHA1="50bdba5ed6693aec1be2e1b04a63c1b0c1ef49fd"

# create initial tag commits
git tag "tag_public_master_${SQ_MERGE_COMMIT_SHA1}" ${PUBLIC_SQ_HEAD_SHA1}
git tag "tag_master_${SQ_MERGE_COMMIT_SHA1}" ${SQ_MERGE_COMMIT_SHA1}

