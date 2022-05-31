#!/bin/sh
set -e

INPUT_FORCE=${INPUT_FORCE:-false}
INPUT_PULL_FIRST=${INPUT_PULL_FIRST:-false}
INPUT_TAGS=${INPUT_TAGS:-false}
INPUT_DIRECTORY=${INPUT_DIRECTORY:-'.'}
_FORCE_OPTION=''
REPOSITORY=${INPUT_REPOSITORY:-$GITHUB_REPOSITORY}

echo "Push to branch $INPUT_BRANCH";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo 'Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".';
    exit 1;
};

if ${INPUT_FORCE}; then
    _FORCE_OPTION='--force'
fi

if ${INPUT_TAGS}; then
    _TAGS='--tags'
fi

cd ${INPUT_DIRECTORY}

remote_repo="${INPUT_GITHUB_URL_PROTOCOL}//${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@${INPUT_GITHUB_URL}/${REPOSITORY}.git"
git config --local --add safe.directory ${INPUT_DIRECTORY}

if ${INPUT_PULL_FIRST}; then
  git pull --rebase
  git push --follow-tags $_FORCE_OPTION $_TAGS;
else
  git push "${remote_repo}" HEAD:${INPUT_BRANCH} --follow-tags $_FORCE_OPTION $_TAGS;
fi


