#!/bin/sh
echo "Push to branch ${INPUT_BRANCH}";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo 'Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".';
    exit 1;
};

header=$(echo -n "ad-m:${INPUT_GITHUB_TOKEN}" | base64)
git -c http.extraheader="AUTHORIZATION: basic $header" push origin HEAD:master;