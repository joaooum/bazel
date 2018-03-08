#!/bin/bash
#
# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

function _log_base() {
  prefix=$1
  line=$2
  shift 2
  echo >&2 "${prefix}[$(basename "${BASH_SOURCE[0]}"):${BASH_LINENO[2]} ($(date "+%H:%M:%S %z"))] $*"
}

function fail() {
  _log_base "FAILED" "$@"
  exit 1
}

function log_fail() {
  # non-fatal version of fail()
  _log_base "FAILED" "$@"
}

function log_info() {
  _log_base "INFO" "$@"
}

which true >&/dev/null || fail "cannot locate GNU coreutils"

case "$(uname -s | tr [:upper:] [:lower:])" in
msys*|mingw*|cygwin*)
  function is_windows() { true; }
  ;;
*)
  function is_windows() { false; }
  ;;
esac

function find_runfiles_sh() {
  # Unset existing definitions of the functions we want to test.
  if type rlocation >&/dev/null; then
    unset rlocation
    unset runfiles_export_envvars
  fi

  # Find runfiles.sh
  if [[ "${RUNFILES_MANIFEST_ONLY:-0}" == "1" ]]; then
    [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]] \
        || fail "RUNFILES_MANIFEST_FILE is undefined"
    local runfiles_sh=$(grep -m1 "^io_bazel/tools/bash/runfiles/runfiles.sh " \
                        "$RUNFILES_MANIFEST_FILE" | cut -d" " -f2-)
  else
    local runfiles_sh=$(dirname $0)/runfiles.sh
  fi
  [[ -f "$runfiles_sh" ]] \
      || fail "cannot find io_bazel/tools/bash/runfiles/runfiles.sh at " \
              "'$runfiles_sh'"

  echo "$runfiles_sh"
}

function test_sourcing_runfiles_sh_requires_envvars() {
  # Assert that runfiles.sh requires at least one of RUNFILES_MANIFEST_FILE and
  # RUNFILES_DIR to be set.
  if (RUNFILES_DIR= RUNFILES_MANIFEST_FILE= RUNFILES_MANIFEST_ONLY= \
      source "$runfiles_sh_path"); then
    fail
  fi
  # Assert that providing at one of the envvars is enough to source runfiles.sh.
  if ! (RUNFILES_DIR=foo RUNFILES_MANIFEST_FILE= \
        source "$runfiles_sh_path"); then
    fail
  fi
}

function test_rlocation_call_requires_envvars() {
  export RUNFILES_DIR=mock/runfiles
  export RUNFILES_MANIFEST_FILE=
  export RUNFILES_MANIFEST_ONLY=
  source "$runfiles_sh_path"

  if ! (rlocation "foo"); then
    fail
  fi
  export RUNFILES_DIR=
  if (rlocation "foo" >&/dev/null); then
    fail
  fi
}

function test_rlocation_argument_validation() {
  export RUNFILES_DIR=mock/runfiles
  export RUNFILES_MANIFEST_FILE=
  export RUNFILES_MANIFEST_ONLY=
  source "$runfiles_sh_path"

  # Test invalid inputs to make sure rlocation catches these.
  if (rlocation "foo/.." >&/dev/null); then
    fail
  fi
  if (rlocation "\\foo" >&/dev/null); then
    fail
  fi
}

function test_rlocation_abs_path() {
  export RUNFILES_DIR=mock/runfiles
  export RUNFILES_MANIFEST_FILE=
  export RUNFILES_MANIFEST_ONLY=
  source "$runfiles_sh_path"

  if is_windows; then
    [[ "$(rlocation "c:/Foo")" == "c:/Foo" ]] || fail
    [[ "$(rlocation "c:\\Foo")" == "c:\\Foo" ]] || fail
  else
    [[ "$(rlocation "/Foo")" == "/Foo" ]] || fail
  fi
}

function test_init_manifest_based_runfiles() {
  local tmpdir="$(mktemp -d $TEST_TMPDIR/tmp.XXXXXXXX)"
  cat > $tmpdir/foo.runfiles_manifest << 'EOF'
a/b c/d
e/f g h
EOF

  export RUNFILES_DIR=
  export RUNFILES_MANIFEST_FILE=$tmpdir/foo.runfiles_manifest
  export RUNFILES_MANIFEST_ONLY=1
  source "$runfiles_sh_path"

  [[ -z "$(rlocation a)" ]] || fail
  [[ "$(rlocation a/b)" == "c/d" ]] || fail
  [[ "$(rlocation e/f)" == "g h" ]] || fail
  [[ -z "$(rlocation c/d)" ]] || fail
}

function test_manifest_based_envvars() {
  local tmpdir="$(mktemp -d $TEST_TMPDIR/tmp.XXXXXXXX)"
  echo "a b" > $tmpdir/foo.runfiles_manifest

  export RUNFILES_DIR=
  export RUNFILES_MANIFEST_FILE=$tmpdir/foo.runfiles_manifest
  export RUNFILES_MANIFEST_ONLY=1
  source "$runfiles_sh_path"

  runfiles_export_envvars
  [[ "${RUNFILES_DIR:-}" == "$tmpdir/foo.runfiles" ]] || fail
  [[ "${RUNFILES_MANIFEST_FILE:-}" == "$tmpdir/foo.runfiles_manifest" ]] || fail
  [[ "${RUNFILES_MANIFEST_ONLY:-}" == 1 ]] || fail
}

function test_init_directory_based_runfiles() {
  export RUNFILES_DIR=mock/runfiles
  export RUNFILES_MANIFEST_FILE=
  export RUNFILES_MANIFEST_ONLY=
  source "$runfiles_sh_path"

  [[ "$(rlocation a)" == "mock/runfiles/a" ]] || fail
  [[ "$(rlocation a/b)" == "mock/runfiles/a/b" ]] || fail
}

function test_directory_based_envvars() {
  export RUNFILES_DIR=mock/runfiles
  export RUNFILES_MANIFEST_FILE=
  export RUNFILES_MANIFEST_ONLY=
  source "$runfiles_sh_path"

  runfiles_export_envvars
  [[ "${RUNFILES_DIR:-}" == "mock/runfiles" ]] || fail
  [[ "${RUNFILES_MANIFEST_FILE:-}" == "mock/runfiles/MANIFEST" ]] || fail
  [[ -z "${RUNFILES_MANIFEST_ONLY:-}" ]] || fail
}

function main() {
  declare runfiles_sh_path=$(find_runfiles_sh)

  local tests=$(declare -F | grep " -f test" | awk '{print $3}')
  local count=$(declare -F | grep -c " -f test")
  local i=1
  for t in $tests; do
    log_info "Testing $i/$count: $t"
    $t
#     if ($t); then
#       log_info "Passed."
#     else
#       log_fail "$t failed"
#     fi
    i=$(($i+1))
  done
}

main
