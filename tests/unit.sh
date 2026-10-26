#!/bin/bash
# Unit tests for start.sh: a fake `git` records its arguments so we can assert
# on option handling without touching a real repository or network.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib.sh"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/git" <<'FAKE'
#!/bin/sh
echo "$*" >> "$GIT_LOG"
[ -n "$GIT_CONFIG_COUNT" ] && echo "env:$GIT_CONFIG_KEY_0=$GIT_CONFIG_VALUE_0" >> "$GIT_LOG"
if [ "$1" = "symbolic-ref" ]; then
    [ "$FAKE_DETACHED" = "true" ] && exit 1
fi
exit 0
FAKE
chmod +x "$SANDBOX/bin/git"

# run_start VAR=value... -> sets OUT (stdout+stderr), CODE, GIT_CALLS (log)
run_start() {
    export GIT_LOG="$SANDBOX/git.log"
    : > "$GIT_LOG"
    OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/bin:$PATH" GIT_LOG="$GIT_LOG" \
        INPUT_BRANCH=main INPUT_GITHUB_TOKEN=tok INPUT_GITHUB_URL_PROTOCOL=https: \
        INPUT_GITHUB_URL=github.com INPUT_REPOSITORY=owner/repo "$@" \
        bash "$ROOT/start.sh" 2>&1)
    CODE=$?
    GIT_CALLS=$(cat "$GIT_LOG")
}
push_line() { grep '^push' "$GIT_LOG"; }
REMOTE="https://github.com/owner/repo.git"
AUTH="http.https://github.com/.extraheader=AUTHORIZATION: basic $(printf oauth2:tok | base64)"

echo "defaults"
run_start
assert_eq "exits 0" 0 "$CODE"
assert_eq "default push command" "push $REMOTE HEAD:main --atomic --follow-tags" "$(push_line)" 

echo "token handling"
run_start
assert_not_contains "token is not in any git argument" "$(grep -v '^env:' "$GIT_LOG")" "tok"
assert_contains "token passed via scoped auth header" "$GIT_CALLS" "env:$AUTH"

echo "validation"
run_start INPUT_GITHUB_TOKEN=
assert_eq "missing token exits 1" 1 "$CODE"
assert_contains "missing token message" "$OUT" "Missing input 'token'"
assert_eq "missing token does not push" "" "$(push_line)"

run_start INPUT_FORCE=true INPUT_FORCE_WITH_LEASE=true
assert_eq "force + force_with_lease exits 1" 1 "$CODE"
assert_contains "force conflict message" "$OUT" "only force or force_with_lease"

echo "push options"
run_start INPUT_ATOMIC=false
assert_not_contains "atomic=false drops --atomic" "$(push_line)" "--atomic"

run_start INPUT_FORCE=true
assert_contains "force adds --force" "$(push_line)" "--force"
assert_not_contains "force is not lease" "$(push_line)" "--force-with-lease"

run_start INPUT_FORCE_WITH_LEASE=true
assert_contains "lease adds --force-with-lease" "$(push_line)" "--force-with-lease"
assert_not_contains "lease omits HEAD refspec" "$(push_line)" "HEAD:main"
assert_not_contains "lease uses default remote" "$(push_line)" "$REMOTE"

run_start INPUT_FORCE_WITH_LEASE=true INPUT_PUSH_ONLY_TAGS=true
assert_contains "lease+only_tags pushes to bare remote" "$(push_line)" "push $REMOTE"

run_start INPUT_PUSH_ONLY_TAGS=true INPUT_TAGS=true
assert_not_contains "only_tags omits HEAD refspec" "$(push_line)" "HEAD:main"
assert_contains "only_tags pushes tags" "$(push_line)" "--tags"

run_start INPUT_TAGS=true
assert_contains "tags adds --tags" "$(push_line)" "--tags"

run_start INPUT_FORCE_WITH_LEASE=true INPUT_TAGS=true
assert_not_contains "lease+tags drops --atomic" "$(push_line)" "--atomic"

run_start INPUT_PUSH_TO_SUBMODULES=on-demand
assert_contains "submodule strategy" "$(push_line)" "--recurse-submodules=on-demand"

run_start INPUT_SSH=true
assert_contains "ssh remote" "$(push_line)" "git@github.com:owner/repo.git"
assert_not_contains "ssh remote has no token" "$GIT_CALLS" "oauth2"
assert_not_contains "ssh sends no auth header" "$GIT_CALLS" "extraheader"

run_start INPUT_GITHUB_URL=ghe.example.com INPUT_BRANCH=release
assert_contains "enterprise url + branch" "$(push_line)" "https://ghe.example.com/owner/repo.git HEAD:release"

echo "detached HEAD"
run_start FAKE_DETACHED=true
assert_eq "detached push still exits 0" 0 "$CODE"
assert_contains "detached warning" "$OUT" "detached HEAD"

echo "pull"
run_start INPUT_PULL=true
assert_contains "pull=true rebases" "$GIT_CALLS" "pull --rebase $REMOTE main"
run_start INPUT_PULL=rebase
assert_contains "pull=rebase" "$GIT_CALLS" "pull --rebase"
run_start INPUT_PULL=merge
assert_contains "pull=merge" "$GIT_CALLS" "pull --no-rebase"
run_start INPUT_PULL=ff-only
assert_contains "pull=ff-only" "$GIT_CALLS" "pull --ff-only"
run_start INPUT_PULL=bogus
assert_eq "unknown strategy exits 1" 1 "$CODE"
assert_contains "unknown strategy message" "$OUT" "Unknown pull strategy"
assert_eq "unknown strategy does not push" "" "$(push_line)"
run_start INPUT_PULL=true FAKE_DETACHED=true
assert_eq "pull on detached HEAD exits 1" 1 "$CODE"
assert_eq "pull on detached HEAD does not push" "" "$(push_line)"
run_start INPUT_PULL=merge INPUT_SSH=true
assert_contains "pull over ssh" "$GIT_CALLS" "pull --no-rebase git@github.com:owner/repo.git main"

echo "directory"
mkdir -p "$SANDBOX/sub dir"
run_start INPUT_DIRECTORY="sub dir"
assert_eq "directory with space works" 0 "$CODE"

summary
