#!/bin/sh
set -e

INPUT_BRANCH=${INPUT_BRANCH:-master}
INPUT_FORCE=${INPUT_FORCE:-false}
INPUT_DIRECTORY=${INPUT_DIRECTORY:-'.'}
_FORCE_OPTION=''

echo "Push to branch $INPUT_BRANCH";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo 'Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".';
    exit 1;
};

if ${INPUT_FORCE}; then
    _FORCE_OPTION='--force'
fi

cd ${INPUT_DIRECTORY}

# Ensure that the remote of the git repository of the current directory still is the repository where the github action is executed
git remote add origin https://github.com/${GITHUB_REPOSITORY} || git remote set-url origin https://github.com/${GITHUB_REPOSITORY} || true

header=$(echo -n "ad-m:${INPUT_GITHUB_TOKEN}" | base64)
git -c http.extraheader="AUTHORIZATION: basic $header" push origin HEAD:${INPUT_BRANCH} --follow-tags $_FORCE_OPTION;
