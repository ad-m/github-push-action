#!/bin/sh
set -eux
echo "Push to branch ${INPUT_BRANCH}";

header=$(echo -n "ad-m:${INPUT_REPO-TOKEN}" | base64)
git -c http.extraheader="AUTHORIZATION: basic $header" push origin refs/remotes/origin/master:master;