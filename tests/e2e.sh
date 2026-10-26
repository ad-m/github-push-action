#!/bin/bash
# End-to-end tests: run start.js (and thus start.sh) with real git against a
# local bare repository. git's insteadOf rewrites the action's HTTPS URL to it.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib.sh"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"; mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name tester
git config --global user.email tester@example.test
git config --global init.defaultBranch main
git config --global protocol.file.allow always

BARE="$SANDBOX/remote.git"
URL="https://example.test/owner/repo.git"
git config --global "url.file://$BARE.insteadOf" "$URL"

# fresh_world: new bare remote with one commit on main, plus a work clone.
fresh_world() {
    rm -rf "$BARE" "$SANDBOX/seed" "$SANDBOX/work"
    git init -q --bare "$BARE"
    git init -q "$SANDBOX/seed"
    (cd "$SANDBOX/seed" && echo base > f && git add f && git commit -qm base \
        && git push -q "$BARE" HEAD:main)
    git clone -q "$BARE" "$SANDBOX/work"
}
commit_in() { (cd "$1" && echo "$2" > "$2" && git add "$2" && git commit -qm "$2"); }
remote_head() { git -C "$BARE" rev-parse "${1:-main}"; }

# action [VAR=value...]: run the action from the work clone.
action() {
    OUT=$(cd "$SANDBOX/work" && env INPUT_BRANCH=main INPUT_TOKEN=tok \
        INPUT_GITHUB_URL=https://example.test INPUT_REPOSITORY=owner/repo \
        GITHUB_REPOSITORY=owner/repo "$@" node "$ROOT/start.js" 2>&1)
    CODE=$?
}

echo "plain push"
fresh_world; commit_in "$SANDBOX/work" a
action
assert_eq "exits 0" 0 "$CODE"
assert_eq "remote main updated" "$(git -C "$SANDBOX/work" rev-parse HEAD)" "$(remote_head)"

echo "non-fast-forward is rejected"
fresh_world; commit_in "$SANDBOX/work" a; commit_in "$SANDBOX/seed" b
(cd "$SANDBOX/seed" && git push -q "$BARE" HEAD:main)
action
assert_eq "exits 1" 1 "$CODE"

echo "force overwrites diverged remote"
action INPUT_FORCE=true
assert_eq "exits 0" 0 "$CODE"
assert_eq "remote main replaced" "$(git -C "$SANDBOX/work" rev-parse HEAD)" "$(remote_head)"

echo "pull rebase integrates remote changes"
fresh_world; commit_in "$SANDBOX/work" a; commit_in "$SANDBOX/seed" b
(cd "$SANDBOX/seed" && git push -q "$BARE" HEAD:main)
action INPUT_PULL=rebase
assert_eq "exits 0" 0 "$CODE"
assert_eq "remote has both commits" 3 "$(git -C "$BARE" rev-list --count main)"

echo "tags"
fresh_world; commit_in "$SANDBOX/work" a; git -C "$SANDBOX/work" tag v1
action INPUT_TAGS=true
assert_eq "exits 0" 0 "$CODE"
assert_eq "tag pushed" "$(git -C "$SANDBOX/work" rev-parse v1)" "$(git -C "$BARE" rev-parse v1)"

echo "directory input"
fresh_world; commit_in "$SANDBOX/work" a
mkdir "$SANDBOX/elsewhere"
OUT=$(cd "$SANDBOX/elsewhere" && env INPUT_BRANCH=main INPUT_TOKEN=tok INPUT_GITHUB_URL=https://example.test \
    INPUT_REPOSITORY=owner/repo INPUT_DIRECTORY="$SANDBOX/work" node "$ROOT/start.js" 2>&1); CODE=$?
assert_eq "exits 0" 0 "$CODE"
assert_eq "pushed from directory" "$(git -C "$SANDBOX/work" rev-parse HEAD)" "$(remote_head)"

echo "push_only_tags"
fresh_world; commit_in "$SANDBOX/work" a; git -C "$SANDBOX/work" tag v2
action INPUT_PUSH_ONLY_TAGS=true INPUT_TAGS=true
assert_eq "exits 0" 0 "$CODE"
assert_eq "tag pushed" "$(git -C "$SANDBOX/work" rev-parse v2)" "$(git -C "$BARE" rev-parse v2)"
assert_eq "branch not pushed" 1 "$(git -C "$BARE" rev-list --count main)"

echo "detached HEAD"
fresh_world; git -C "$SANDBOX/work" checkout -q --detach
action
assert_contains "warns" "$OUT" "detached HEAD"
action INPUT_PULL=true
assert_eq "pull on detached HEAD exits 1" 1 "$CODE"

echo "validation"
fresh_world
action INPUT_TOKEN= INPUT_GITHUB_TOKEN=
assert_eq "missing token exits 1" 1 "$CODE"

summary
