#!/bin/bash
#
# Copyright 2017 The Bazel Authors. All rights reserved.
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
  shift
  echo >&2 "${prefix}[$(basename "$0"):${BASH_LINENO[1]} ($(date "+%H:%M:%S.%N %z"))] $*"
}

function fail() {
  _log_base "FAILED" "$@"
  exit 1
}

function assert_true() {
  if ! $*; then
    fail
  fi
}

function assert_false() {
  if $*; then
    fail
  fi
}

stat "$0" >&/dev/null || fail "cannot locate GNU coreutils"

# Find runfiles.sh. The test framework defines rlocation, so use that.
runfiles_sh=$(rlocation "io_bazel/tools/bash/runfiles/runfiles.sh")
[[ -f "$runfiles_sh" ]] || fail "cannot find runfiles.sh at '$runfiles_sh'"

# Unset existing definitions of the functions we want to test.
if type rlocation >&/dev/null; then
  unset is_absolute
  unset is_windows
  unset rlocation
fi

# Set mock runfiles directory.
export RUNFILES_DIR=mock/runfiles
source "$runfiles_sh" || fail "cannot source '$runfiles_sh'"

# Exercise is_absolute in runfiles.sh.
if is_windows; then
  assert_true is_absolute "d:/Foo"
  assert_true is_absolute "d:\\Foo"
  assert_false is_absolute "\\Foo"
else
  assert_true is_absolute "/foo"
  assert_false is_absolute "d:/Foo"
fi
assert_false is_absolute "foo"
assert_false is_absolute "foo/bar"

# Exercise rlocation in runfiles.sh.
[[ "$(rlocation "some/runfile")" == "mock/runfiles/some/runfile" ]] || fail
[[ "$(rlocation "/some absolute/runfile")" = "/some absolute/runfile" ]] || fail
