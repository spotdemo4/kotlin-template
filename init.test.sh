#!/usr/bin/env bash
# The tests often single-quote text containing $
# shellcheck disable=SC2016

# Tests init.sh. The init flake check runs it from a copy of the template.

set -euo pipefail

# shellcheck source=init.sh
source ./init.sh

template=$PWD
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/home/.config GIT_CONFIG_NOSYSTEM=1
mkdir "$HOME"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual=$1 expected=$2 name=$3
  if [[ $actual != "$expected" ]]; then
    fail "$name: expected '$expected', got '$actual'"
  fi
}

# Runs a command that must fail with the expected output.
assert_fails() {
  local expected=$1 output
  shift
  if output=$("$@" 2>&1); then
    fail "$* succeeded"
  fi
  assert_eq "$output" "$expected" "$*"
}

assert_contains() {
  local file=$1 text
  shift
  for text in "$@"; do
    grep -qF -- "$text" "$file" || fail "$file does not contain '$text'"
  done
}

assert_lacks() {
  local file=$1 text
  shift
  for text in "$@"; do
    if grep -qF -- "$text" "$file"; then
      fail "$file contains '$text'"
    fi
  done
}

assert_missing() {
  local path
  for path in "$@"; do
    if [[ -e $path ]]; then
      fail "$path exists"
    fi
  done
}

test_parse_remote() {
  local url expected
  while read -r url expected; do
    parse_remote 'Origin URL' "$url"
    assert_eq "$remote_host $remote_repo_path $remote_web_url" "$expected" "parse_remote $url"
  done <<'EOF'
https://github.com/octo/hello.git github.com octo/hello https://github.com/octo/hello
http://user@git.example.com:3000/octo/hello git.example.com:3000 octo/hello http://git.example.com:3000/octo/hello
git@github.com:octo/hello.git github.com octo/hello https://github.com/octo/hello
ssh://git@git.example.com:2222/group/sub/hello.git git.example.com group/sub/hello https://git.example.com/group/sub/hello
EOF

  assert_fails 'Origin URL cannot contain a query string or fragment.' parse_remote 'Origin URL' 'https://github.com/octo/hello?tab=readme'
  assert_fails 'Unsupported repository URL.' parse_remote 'Repository URL' 'ftp://github.com/octo/hello'
  assert_fails 'Origin URL must identify an owner and repository.' parse_remote 'Origin URL' 'git@github.com:hello.git'
  assert_fails 'Origin URL contains unsupported host or path characters.' parse_remote 'Origin URL' 'https://github.com/octo/hello world'
}

test_slugify() {
  assert_eq "$(slugify 'Hello World')" hello-world 'slugify Hello World'
  assert_eq "$(slugify ' My_App 2! ')" my-app-2 'slugify My_App 2!'
  assert_fails 'Title must produce a package name beginning with a letter.' slugify '2048'
  assert_fails 'Title must produce a package name beginning with a letter.' slugify '!!!'
}

test_maven_group() {
  assert_eq "$(maven_group github.com Octo/hello)" com.github.octo 'maven_group github.com'
  assert_eq "$(maven_group git.example.com octo/hello)" com.example.git.octo 'maven_group git.example.com'
}

test_kotlin_package() {
  local message='Origin and title must produce a Kotlin package name without keywords or parts that are empty or begin with a digit.'
  assert_eq "$(kotlin_package com.github.octo hello-world)" com.github.octo.helloworld 'kotlin_package hello-world'
  assert_eq "$(kotlin_package com.example.git.my-org hello)" com.example.git.myorg.hello 'kotlin_package my-org'
  assert_fails "$message" kotlin_package com.github.octo object
  assert_fails "$message" kotlin_package com.github.in hello
  assert_fails "$message" kotlin_package com.github.1password hello
  assert_fails "$message" kotlin_package com.github..octo hello
}

test_nix_string() {
  assert_eq "$(nix_string 'Say "hi" to ${USER} \o/')" 'Say \"hi\" to \${USER} \\o/' nix_string
}

# Creates the template's upstream repository, which init.sh fetches to find the
# template commit.
create_upstream() {
  git init --quiet "$tmp/upstream"
  cp -a "$template/." "$tmp/upstream"
  git -C "$tmp/upstream" add -A
  git -C "$tmp/upstream" commit --quiet --message 'feat: template'
  git config --global url."$tmp/upstream".insteadOf "$old_url"
  upstream_commit=$(git -C "$tmp/upstream" rev-parse HEAD)
}

# Copies the template into a new repository with an origin remote.
new_project() {
  local dir=$1 origin=$2
  git init --quiet "$dir"
  cp -a "$template/." "$dir"
  git -C "$dir" remote add origin "$origin"
}

# Checks what init.sh does for every project in the current directory.
assert_initialized() {
  local group=$1 slug=$2 email=$3
  assert_missing init.sh init.test.sh template.schema.json
  assert_eq "$(git log --format='%an <%ae> %s')" "Test User <$email> chore: initialize project" 'commits'
  assert_eq "$(git status --porcelain --untracked-files=all)" '' 'worktree status'
  assert_eq "$(jq -r .commit .template.json)" "$upstream_commit" '.template.json commit'
  assert_eq "$(git grep -n -e kotlin-template -e trev.zip/template -e template/kotlin -e init.sh -e init.test.sh -- ':!.template.json' ':!AGENTS.md' || true)" '' 'template references'
  assert_contains settings.gradle.kts "rootProject.name = \"$slug\""
  assert_contains build.gradle.kts "group = \"$group\"" 'version = "0.0.1"'
  assert_contains flake.nix "pname = \"$slug\";" 'version = "0.0.1";'
  assert_contains LICENSE "Copyright (c) $(date +%Y) Test User"
  assert_lacks flake.nix GRADLE_DEPS
  assert_lacks .gitattributes 'exclude template'
}

# Builds and tests the library in the current directory. The build sandbox can't
# download dependencies, so Gradle resolves them from the template's cache of
# its dependencies, which GRADLE_DEPS names.
build_library() {
  if [[ -z ${GRADLE_DEPS-} ]]; then
    printf 'skipped: GRADLE_DEPS is not set\n'
    return
  fi
  cat >"$tmp/offline.init.gradle" <<EOF
beforeSettings { settings ->
  settings.pluginManagement.repositories {
    clear()
    maven { url = uri("file://$GRADLE_DEPS/https/plugins.gradle.org/m2") }
    maven { url = uri("file://$GRADLE_DEPS/https/repo.maven.apache.org/maven2") }
  }
}
allprojects {
  repositories {
    clear()
    maven { url = uri("file://$GRADLE_DEPS/https/repo.maven.apache.org/maven2") }
  }
}
EOF
  GRADLE_USER_HOME=$tmp/gradle gradle --offline --no-daemon --console=plain \
    --init-script "$tmp/offline.init.gradle" jar test
  [[ -f build/libs/hello-lib-0.0.1.jar ]] || fail 'the jar is missing'
}

test_application() (
  local project=$tmp/hello-world description='Says "hi" to ${USER} \o/'
  new_project "$project" git@github.com:octo/hello-world.git
  cd "$project"
  # "use this template" creates a new commit with the template's tree
  git add -A
  git commit --quiet --message 'Initial commit'
  # The build sandbox has no /usr/bin/env for the shebang
  printf '%s\n' n n https://git.example.com/octo/hello-world '' '' | bash ./init.sh 'Hello World' "$description"

  assert_initialized com.github.octo hello-world test@example.com
  assert_eq "$(jq -r .library .template.json)" null '.template.json library'
  assert_eq "$(git remote)" $'forgejo\norigin' remotes
  assert_eq "$(head -n 1 README.md)" '# Hello World' 'README title'
  assert_contains README.md "$description" \
    'nix run git+https://github.com/octo/hello-world.git' \
    'docker run ghcr.io/octo/hello-world:latest' \
    'https://github.com/octo/hello-world/releases'
  assert_contains flake.nix \
    'description = "Says \"hi\" to \${USER} \\o/";' \
    'mainProgram = "hello-world";' \
    'homepage = "https://github.com/octo/hello-world";' \
    'actions-gh = {' 'actions-fj = {' \
    'name = "Test User";' 'email = "test@example.com";'
  assert_lacks flake.nix "$old_maintainer"
  assert_contains .github/renovate.jsonc '"repositories": ["octo/hello-world"]'
  assert_contains .forgejo/renovate.jsonc \
    '"endpoint": "https://git.example.com/api/v1"' \
    '"repositories": ["octo/hello-world"]'
  [[ -f src/main/kotlin/Main.kt && -d .zed && -d .vscode ]] || fail 'application files are missing'
)

test_library() (
  local project=$tmp/hello-lib
  new_project "$project" https://git.example.com/octo/hello-lib.git
  cd "$project"
  # nix flake init leaves the template uncommitted and init.sh not executable
  chmod -x init.sh
  # The template's author keeps their maintainer entry
  git config user.email Me@Trev.xyz
  printf '%s\n' y y n n | bash init.sh 'Hello Lib' 'Says hello'

  assert_initialized com.example.git.octo hello-lib Me@Trev.xyz
  assert_eq "$(jq -r .library .template.json)" true '.template.json library'
  assert_contains flake.nix "maintainers = [ $old_maintainer ];"
  assert_eq "$(git remote)" origin remotes
  assert_missing src/main/kotlin/Main.kt src/test/kotlin/MainTest.kt .github .zed .vscode
  assert_contains src/main/kotlin/com/example/git/octo/hellolib/Hello.kt \
    'package com.example.git.octo.hellolib' 'fun hello(name: String): String'
  assert_contains src/test/kotlin/com/example/git/octo/hellolib/HelloTest.kt 'package com.example.git.octo.hellolib'
  assert_contains build.gradle.kts '`java-library`'
  assert_lacks build.gradle.kts application mainClass
  assert_contains README.md \
    'maven("https://git.example.com/api/packages/octo/maven")' \
    'implementation("com.example.git.octo:hello-lib:latest.release")'
  assert_lacks README.md 'nix run' 'docker run'
  assert_contains flake.nix 'gradleBuildTask = "jar";' 'cp build/libs/*.jar "$out/share/java"'
  assert_lacks flake.nix mainProgram downloadPage installCheckPhase makeWrapper wrapProgram installDist \
    'images = {' 'appimages = {' 'actions-gh = {' 'renovate-gh = {'
  assert_contains .forgejo/workflows/release.yaml 'PACKAGES: packages.x86_64-linux.default'
  assert_lacks .forgejo/workflows/release.yaml CONTAINER_REGISTRY_PASSWORD images.x86_64-linux appimages.x86_64-linux
  assert_lacks CONTRIBUTING.md '### run' installDist
  build_library
)

test_library_github() (
  local project=$tmp/hello-github
  new_project "$project" git@github.com:octo/hello-github.git
  cd "$project"
  git add -A
  git commit --quiet --message 'Initial commit'
  printf '%s\n' y y n n | bash ./init.sh 'Hello GitHub' 'Says hello'

  assert_initialized com.github.octo hello-github test@example.com
  assert_missing .forgejo
  assert_contains src/main/kotlin/com/github/octo/hellogithub/Hello.kt 'package com.github.octo.hellogithub'
  assert_contains README.md 'maven("https://maven.pkg.github.com/octo/hello-github") {' \
    'implementation("com.github.octo:hello-github:latest.release")'
  assert_contains .github/workflows/release.yaml 'packages: write' 'PACKAGE_REGISTRY_TOKEN' 'PACKAGES: packages.x86_64-linux.default'
  assert_lacks .github/workflows/release.yaml images.x86_64-linux appimages.x86_64-linux
)

test_rollback() (
  local project=$tmp/rollback head
  new_project "$project" git@github.com:octo/rollback.git
  cd "$project"
  git add -A
  git commit --quiet --message 'Initial commit'
  head=$(git rev-parse HEAD)

  touch untracked
  assert_fails 'Commit or discard all existing worktree changes before running the initializer.' \
    bash ./init.sh Rollback Rollback </dev/null
  rm untracked

  # The Forgejo URL is read after the template has been changed
  assert_fails 'Unsupported repository URL.' \
    bash ./init.sh Rollback Rollback < <(printf '%s\n' n n ftp://git.example.com/octo/rollback)
  assert_eq "$(git rev-parse HEAD)" "$head" HEAD
  assert_eq "$(git status --porcelain --untracked-files=all)" '' 'worktree status'
  assert_missing "$tmp"/.rollback.git-*
)

git config --global user.name 'Test User'
git config --global user.email test@example.com
git config --global init.defaultBranch main

# nix fmt can't evaluate the flake in the build sandbox, so run its formatter
mkdir "$tmp/bin"
printf '#!%s\n[[ $* == fmt ]] && TREEFMT_TREE_ROOT=$PWD exec treefmt\nexit 1\n' "$BASH" >"$tmp/bin/nix"
chmod +x "$tmp/bin/nix"
PATH=$tmp/bin:$PATH

create_upstream
for test in test_parse_remote test_slugify test_maven_group test_kotlin_package test_nix_string test_application test_library test_library_github test_rollback; do
  "$test"
  printf 'ok: %s\n' "$test"
done
