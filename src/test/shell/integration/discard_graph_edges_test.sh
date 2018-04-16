#!/bin/bash
#
# Copyright 2016 The Bazel Authors. All rights reserved.
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
#
# discard_graph_edges_test.sh: basic tests for the --discard_graph_edges flag.

# Load the test setup defined in the parent directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/../integration_test_setup.sh" \
  || { echo "integration_test_setup.sh not found!" >&2; exit 1; }
source "${CURRENT_DIR}/discard_graph_edges_lib.sh" \
  || { echo "${CURRENT_DIR}/discard_graph_edges_lib.sh not found!" >&2; exit 1; }

#### SETUP #############################################################

set -e

function set_up() {
  mkdir -p testing || fail "Couldn't create directory"
  echo "cc_test(name='mytest', srcs=['mytest.cc'], malloc=':system_malloc')" > testing/BUILD || fail
  echo "cc_library(name='system_malloc', srcs=[])"                           >> testing/BUILD || fail
  echo "int main() {return 0;}"         > testing/mytest.cc || fail
}

export BUILD_FLAGS="${BUILD_FLAGS:-}  --noexperimental_ui --show_loading_progress"

#### TESTS #############################################################

function prepare_histogram() {
  readonly local build_args="$1"
  rm -rf histodump
  mkdir -p histodump || fail "Couldn't create directory"
  readonly local server_pid_fifo="$TEST_TMPDIR/server_pid"
cat > histodump/foo.bzl <<'EOF' || fail "Couldn't create bzl file"
def foo():
  pass
EOF
cat > histodump/bar.bzl <<'EOF' || fail "Couldn't create bzl file"
def bar():
  pass
EOF
cat > histodump/baz.bzl <<'EOF' || fail "Couldn't create bzl file"
def baz():
  pass
EOF

  cat > histodump/BUILD <<EOF || fail "Couldn't create BUILD file"
load(":foo.bzl", "foo")
load(":bar.bzl", "bar")
load(":baz.bzl", "baz")
cc_library(name = 'cclib', srcs = ['cclib.cc'])
genrule(name = 'histodump',
        srcs = glob(["*.in"]),
        outs = ['histo.txt'],
        local = 1,
        tools = [':cclib'],
        cmd = 'server_pid=\$\$(cat $server_pid_fifo) ; ' +
              '${bazel_javabase}/bin/jmap -histo:live \$\$server_pid > ' +
              '\$(location histo.txt) ' +
              '|| echo "server_pid in genrule: \$\$server_pid"'
       )
EOF

  touch histodump/cclib.cc
  rm -f "$server_pid_fifo"
  mkfifo "$server_pid_fifo"
  histo_file="$(bazel info "${PRODUCT_NAME}-genfiles" \
      2> /dev/null)/histodump/histo.txt"
  bazel clean --expunge >& "$TEST_log" || fail "Couldn't clean"
  readonly local explicit_server_pid="$(bazel $STARTUP_FLAGS info server_pid)"
  bazel $STARTUP_FLAGS build --show_timestamps $build_args \
      //histodump:histodump >> "$TEST_log" 2>&1 &
  readonly local subshell_pid=$!
  # We plan to remove batch mode from the relevant flags for discarding
  # incrementality state. In the interim, tests that are not in batch mode
  # explicitly pass --nobatch, so we can use it as a signal.
  if [[ "$STARTUP_FLAGS" =~ "--nobatch" ]]; then
    server_pid="$explicit_server_pid"
  else
    server_pid="$subshell_pid"
  fi
  echo "DEBUG: server_pid in main thread is ${server_pid}" >> "$TEST_log"
  echo "$server_pid" > "$server_pid_fifo"
  echo "DEBUG: Finished writing pid to fifo at " >> "$TEST_log"
  date >> "$TEST_log"
  # Wait for previous command to finish.
  wait "$subshell_pid" || fail "Bazel command failed"
  cat "$histo_file" >> "$TEST_log"
  echo "$histo_file"
}

# TODO(b/62450749): This is flaky on CI.
function test_packages_cleared() {
#  local histo_file="$(prepare_histogram "--nodiscard_analysis_cache")"
#  local package_count="$(extract_histogram_count "$histo_file" \
#      'devtools\.build\.lib\..*\.Package$')"
#  [[ "$package_count" -ge 9 ]] \
#      || fail "package count $package_count too low: did you move/rename the class?"
#  local glob_count="$(extract_histogram_count "$histo_file" "GlobValue$")"
#  [[ "$glob_count" -ge 8 ]] \
#      || fail "glob count $glob_count too low: did you move/rename the class?"
#  local env_count="$(extract_histogram_count "$histo_file" \
#      'Environment\$Extension$')"
#  [[ "$env_count" -ge 3 ]] \
#      || fail "env extension count $env_count too low: did you move/rename the class?"
#  local ct_count="$(extract_histogram_count "$histo_file" \
#       'RuleConfiguredTarget$')"
#  [[ "$ct_count" -ge 18 ]] \
#      || fail "RuleConfiguredTarget count $ct_count too low: did you move/rename the class?"
#  local edgeless_entry_count="$(extract_histogram_count "$histo_file" \
#       'EdgelessInMemoryNodeEntry')"
#  [[ "$edgeless_entry_count" -eq 0 ]] \
#      || fail "$edgless_entry_count EdgelessInMemoryNodeEntry instances found in build keeping edges"
#  local node_entry_count="$(extract_histogram_count "$histo_file" \
#       '\.InMemoryNodeEntry')"
#  [[ "$node_entry_count" -ge 100 ]] \
#      || fail "Only $node_entry_count InMemoryNodeEntry instances found in build keeping edges"

  local histo_file="$(prepare_histogram "$BUILD_FLAGS")"
  package_count="$(extract_histogram_count "$histo_file" \
      'devtools\.build\.lib\..*\.Package$')"
  # A few packages aren't cleared.
  if ! [[ "$package_count" -le 8 ]]; then
    echo >&2 "DEBUG: --- log ---"
    cat >&2 $TEST_log
    echo >&2 "DEBUG: --- done ---"
    fail "package count $package_count too high"
  fi
  glob_count="$(extract_histogram_count "$histo_file" "GlobValue$")"
  [[ "$glob_count" -le 1 ]] \
      || fail "glob count $glob_count too high"
  env_count="$(extract_histogram_count "$histo_file" \
      'Environment\$  Extension$')"
  [[ "$env_count" -le 7 ]] \
      || fail "env extension count $env_count too high"
  ct_count="$(extract_histogram_count "$histo_file" \
       'RuleConfiguredTarget$')"
  [[ "$ct_count" -le 1 ]] \
      || fail "too many RuleConfiguredTarget: expected at most 1, got $ct_count"
  edgeless_entry_count="$(extract_histogram_count "$histo_file" \
       'EdgelessInMemoryNodeEntry')"
  [[ "$edgeless_entry_count" -ge 100 ]] \
      || fail "Not enough ($edgless_entry_count) EdgelessInMemoryNodeEntry instances found in build discarding edges"
  node_entry_count="$(extract_histogram_count "$histo_file" \
       '\.InMemoryNodeEntry')"
  [[ "$node_entry_count" -le 10 ]] \
      || fail "Too many ($node_entry_count) InMemoryNodeEntry instances found in build discarding edges"
}

run_suite "test for --discard_graph_edges"
