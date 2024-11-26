#!/bin/sh
set -e

INPUT_ATOMIC=${INPUT_ATOMIC:-true}
INPUT_FORCE=${INPUT_FORCE:-false}
INPUT_FORCE_WITH_LEASE=${INPUT_FORCE_WITH_LEASE:-false}
INPUT_SSH=${INPUT_SSH:-false}
INPUT_TAGS=${INPUT_TAGS:-false}
INPUT_PUSH_ONLY_TAGS=${INPUT_PUSH_ONLY_TAGS:-false}
INPUT_DIRECTORY=${INPUT_DIRECTORY:-"."}
INPUT_PUSH_TO_SUBMODULES=${INPUT_PUSH_TO_SUBMODULES:-""}
_ATOMIC_OPTION=""
_FORCE_OPTION=""
REPOSITORY=${INPUT_REPOSITORY:-$GITHUB_REPOSITORY}

echo "Push to branch $INPUT_BRANCH";
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo "Missing input 'github_token: ${{ secrets.GITHUB_TOKEN }}'.";
    exit 1;
};

if ${INPUT_FORCE} && ${INPUT_FORCE_WITH_LEASE}; then
  echo "Please, specify only force or force_with_lease and not both.";
  exit 1;
fi

if ${INPUT_ATOMIC}; then
    _ATOMIC_OPTION="--atomic"
fi

if ${INPUT_FORCE}; then
    _FORCE_OPTION="--force"
fi

if ${INPUT_FORCE_WITH_LEASE}; then
    _FORCE_OPTION="--force-with-lease"
fi

if ${INPUT_TAGS}; then
    _TAGS="--tags"
fi

if [ -n "${INPUT_PUSH_TO_SUBMODULES}" ]; then
  _INPUT_PUSH_TO_SUBMODULES="--recurse-submodules=${INPUT_PUSH_TO_SUBMODULES}"
fi

cd ${INPUT_DIRECTORY}

if ${INPUT_SSH}; then
    remote_repo="git@${INPUT_GITHUB_URL}:${REPOSITORY}.git"
else
    remote_repo="${INPUT_GITHUB_URL_PROTOCOL}//oauth2:${INPUT_GITHUB_TOKEN}@${INPUT_GITHUB_URL}/${REPOSITORY}.git"
fi

if ! ${INPUT_FORCE_WITH_LEASE}; then
  ADDITIONAL_PARAMETERS="${remote_repo} HEAD:${INPUT_BRANCH}"
elif ${INPUT_PUSH_ONLY_TAGS}; then
  ADDITIONAL_PARAMETERS="${remote_repo}"
fi

if ${INPUT_FORCE_WITH_LEASE} && ${INPUT_TAGS}; then
  _ATOMIC_OPTION=""
fi

GIT_PUSH_CMD="git push $ADDITIONAL_PARAMETERS $_INPUT_PUSH_TO_SUBMODULES $_ATOMIC_OPTION --follow-tags $_FORCE_OPTION $_TAGS"

# Execute git push command and capture return value
if eval "$GIT_PUSH_CMD" > /dev/null 2>&1; then
    : # Push successful, do noting
else
    echo "Push failed, trying rebase..."
    if git pull --rebase > /dev/null 2>&1; then
        echo "Rebase successful, trying push again..."
        eval "$GIT_PUSH_CMD" || exit 1
    else
        echo "Rebase failed"
        git rebase --abort
        exit 1
    fi
fi
