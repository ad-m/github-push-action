#!/bin/sh

INPUT_BRANCH:='master'
INPUT_FORCE:=false
_FORCE_OPTION=''

echo "Push to branch $INPUT_BRANCH";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo 'Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".';
    exit 1;
};

if ${INPUT_FORCE}; then
    _FORCE_OPTION='--force'
fi

header=$(echo -n "ad-m:${INPUT_GITHUB_TOKEN}" | base64)
git -c http.extraheader="AUTHORIZATION: basic $header" push origin HEAD:${INPUT_BRANCH} --follow-tags $_FORCE_OPTION;
