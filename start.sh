#!/bin/sh
echo "Push to branch $BRANCH";

header=$(echo -n "ad-m:$INPUT_REPO_TOKEN" | base64)
git -c http.extraheader="AUTHORIZATION: basic $header" push origin refs/remotes/origin/master:master;