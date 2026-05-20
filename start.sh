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
INPUT_PULL=${INPUT_PULL:-false}
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

if [ "${INPUT_PULL}" != "false" ]; then
  if ! git symbolic-ref --quiet HEAD > /dev/null 2>&1; then
    echo "Error: 'pull' is enabled but the repository is in detached HEAD state."
    echo "git pull only works when a branch is currently checked out."
    echo "Either disable the 'pull' input or check out a branch explicitly"
    echo "(e.g. add 'ref: \${{ github.head_ref }}' to the actions/checkout step)."
    exit 1
  fi

  if ${INPUT_SSH}; then
    _pull_remote="git@${INPUT_GITHUB_URL}:${REPOSITORY}.git"
  else
    _pull_remote="${INPUT_GITHUB_URL_PROTOCOL}//oauth2:${INPUT_GITHUB_TOKEN}@${INPUT_GITHUB_URL}/${REPOSITORY}.git"
  fi

  case "${INPUT_PULL}" in
    rebase|true)
      _pull_strategy="--rebase"
      ;;
    merge)
      _pull_strategy="--no-rebase"
      ;;
    ff-only)
      _pull_strategy="--ff-only"
      ;;
    *)
      echo "Unknown pull strategy: '${INPUT_PULL}'. Use rebase, merge, ff-only, or true."
      exit 1
      ;;
  esac

  echo "Pulling from ${INPUT_BRANCH} (strategy: ${INPUT_PULL}) before push..."
  git pull ${_pull_strategy} "${_pull_remote}" "${INPUT_BRANCH}"
fi

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

git push $ADDITIONAL_PARAMETERS $_INPUT_PUSH_TO_SUBMODULES $_ATOMIC_OPTION --follow-tags $_FORCE_OPTION $_TAGS;
