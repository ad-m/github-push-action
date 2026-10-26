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
REPOSITORY=${INPUT_REPOSITORY:-$GITHUB_REPOSITORY}

if ${INPUT_PUSH_ONLY_TAGS}; then
  echo "Push only tags";
else
  echo "Push to branch $INPUT_BRANCH";
fi
[ -z "${INPUT_GITHUB_TOKEN}" ] && {
    echo "Missing input 'token' (or legacy 'github_token'). Please set one of:";
    echo "  token: \${{ secrets.GITHUB_TOKEN }}";
    echo "  github_token: \${{ secrets.GITHUB_TOKEN }}";
    exit 1;
};

if [ "${INPUT_FORCE}" = "true" ] && [ "${INPUT_FORCE_WITH_LEASE}" = "true" ]; then
  echo "Please, specify only force or force_with_lease and not both.";
  exit 1;
fi

cd "${INPUT_DIRECTORY}"

if git symbolic-ref --quiet HEAD > /dev/null 2>&1; then
    _DETACHED_HEAD=false
else
    _DETACHED_HEAD=true
fi

if [ "${_DETACHED_HEAD}" = "true" ]; then
    echo "Warning: The repository is in a detached HEAD state.";
    echo "This happens when actions/checkout checks out a tag, a commit SHA, or a";
    echo "pull-request merge commit rather than a real branch.";
    echo "To resolve this, check out a branch explicitly in your actions/checkout step,";
    echo "for example: 'ref: \${{ github.head_ref }}' or 'ref: main'.";
    echo "Note: setting this action's 'branch' input (e.g. branch: main) only controls";
    echo "the push destination — it does not check out a branch in your workspace.";
fi

# Resolved once and shared by pull and push. The token is not embedded in the
# URL (it would show up in process arguments and git error messages); it is
# handed to git through its environment as a host-scoped auth header instead.
if [ "${INPUT_SSH}" = "true" ]; then
    remote_repo="git@${INPUT_GITHUB_URL}:${REPOSITORY}.git"
else
    remote_repo="${INPUT_GITHUB_URL_PROTOCOL}//${INPUT_GITHUB_URL}/${REPOSITORY}.git"
    _auth=$(printf 'oauth2:%s' "${INPUT_GITHUB_TOKEN}" | base64 | tr -d '\n')
    _n=${GIT_CONFIG_COUNT:-0}
    export "GIT_CONFIG_KEY_${_n}=http.${INPUT_GITHUB_URL_PROTOCOL}//${INPUT_GITHUB_URL}/.extraheader"
    export "GIT_CONFIG_VALUE_${_n}=AUTHORIZATION: basic ${_auth}"
    export GIT_CONFIG_COUNT=$((_n + 1))
fi

if [ "${INPUT_PULL}" != "false" ]; then
  if [ "${_DETACHED_HEAD}" = "true" ]; then
    echo "Error: 'pull' is enabled but the repository is in detached HEAD state."
    echo "git pull only works when a branch is currently checked out."
    echo "Either disable the 'pull' input or check out a branch explicitly"
    echo "(e.g. add 'ref: \${{ github.head_ref }}' to the actions/checkout step)."
    exit 1
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
  git pull "${_pull_strategy}" "${remote_repo}" "${INPUT_BRANCH}"
fi

# Build the push argument list; "$@" keeps each argument intact (no word splitting).
set --
if [ "${INPUT_PUSH_ONLY_TAGS}" = "true" ]; then
  # Never pushes the branch, only tags.
  set -- "${remote_repo}"
elif [ "${INPUT_FORCE_WITH_LEASE}" != "true" ]; then
  set -- "${remote_repo}" "HEAD:${INPUT_BRANCH}"
fi

[ -n "${INPUT_PUSH_TO_SUBMODULES}" ] && set -- "$@" "--recurse-submodules=${INPUT_PUSH_TO_SUBMODULES}"

# --atomic is incompatible with --force-with-lease combined with --tags.
if [ "${INPUT_ATOMIC}" = "true" ] && ! { [ "${INPUT_FORCE_WITH_LEASE}" = "true" ] && [ "${INPUT_TAGS}" = "true" ]; }; then
  set -- "$@" "--atomic"
fi

set -- "$@" "--follow-tags"

[ "${INPUT_FORCE}" = "true" ] && set -- "$@" "--force"
[ "${INPUT_FORCE_WITH_LEASE}" = "true" ] && set -- "$@" "--force-with-lease"
if [ "${INPUT_TAGS}" = "true" ] || [ "${INPUT_PUSH_ONLY_TAGS}" = "true" ]; then
  set -- "$@" "--tags"
fi

git push "$@"
