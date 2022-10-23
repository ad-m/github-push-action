#!/bin/sh
set -e

INPUT_ATOMIC=${INPUT_ATOMIC:-true}
INPUT_FORCE=${INPUT_FORCE:-false}
INPUT_FORCE_WITH_LEASE=${INPUT_FORCE_WITH_LEASE:-false}
INPUT_SSH=${INPUT_SSH:-false}
INPUT_TAGS=${INPUT_TAGS:-false}
INPUT_DIRECTORY=${INPUT_DIRECTORY:-'.'}
_ATOMIC_OPTION=''
_FORCE_OPTION=''
REPOSITORY=${INPUT_REPOSITORY:-$GITHUB_REPOSITORY}

echo "Push to branch $INPUT_BRANCH";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo 'Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".';
    exit 1;
};

if ${INPUT_FORCE} && ${INPUT_FORCE_WITH_LEASE}; then
  echo 'Please, specify only force or force_with_lease and not both.';
  exit 1;
fi

if ${INPUT_ATOMIC}; then
    _ATOMIC_OPTION='--atomic'
fi

if ${INPUT_FORCE}; then
    _FORCE_OPTION='--force'
fi

if ${INPUT_FORCE_WITH_LEASE}; then
    _FORCE_OPTION='--force-with-lease'
fi

if ${INPUT_TAGS}; then
    _TAGS='--tags'
fi

cd ${INPUT_DIRECTORY}

if ${INPUT_SSH}; then
    remote_repo="git@${INPUT_GITHUB_URL}:${REPOSITORY}.git"
else
    remote_repo="${INPUT_GITHUB_URL_PROTOCOL}//${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@${INPUT_GITHUB_URL}/${REPOSITORY}.git"
fi

git config --local --add safe.directory ${INPUT_DIRECTORY}

if ! ${INPUT_FORCE_WITH_LEASE}; then
  ADDITIONAL_PARAMETERS="${remote_repo} HEAD:${INPUT_BRANCH}"
fi

git push $ADDITIONAL_PARAMETERS $_ATOMIC_OPTION --follow-tags $_FORCE_OPTION $_TAGS;
