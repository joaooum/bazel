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

# This script defines utility functions to handle sh_binary/sh_test runfiles.
#
# This script requires that at least one of $RUNFILES_MANIFEST_FILE or
# $RUNFILES_DIR be set, otherwise the script fails.
#
# Usage:
#
# 1. Depend on this runfiles library from your build rule:
#
#      sh_binary(
#          name = "my_binary",
#          ...
#          deps = ["@bazel_tools//tools/runfiles:sh-runfiles"],
#      )
#
# 2. Source the runfiles library.
#    Since the runfiles library itself defines rlocation which you would need to
#    look up the library's runtime location, we have a chicken-and-egg problem.
#    Therefore you need to insert the following code snippet to the top of your
#    main script:
#
#
#      set -euo pipefail
#      # --- begin runfiles.sh initialization ---
#      if [[ -z "${RUNFILES_MANIFEST_FILE:-}" && -z "${RUNFILES_DIR:-}" ]]; then
#        if [[ -f "$0.runfiles_manifest" ]]; then
#          export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
#        elif [[ -f "$0.runfiles/MANIFEST" ]]; then
#          export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
#        elif [[ -d "$0.runfiles" ]]; then
#          export RUNFILES_DIR="$0.runfiles" 
#        fi
#      fi
#      if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
#        source "$(grep -m1 "^bazel_tools/tools/runfiles/runfiles.sh " \
#                  "${RUNFILES_MANIFEST_FILE}" | cut -d ' ' -f 2-)"
#      elif [[ -n "${RUNFILES_DIR:-}" ]]; then
#        source "${RUNFILES_DIR}/bazel_tools/tools/runfiles/runfiles.sh"
#      else
#        echo >&2 "ERROR: cannot find @bazel_tools//tools/runfiles:runfiles.sh"
#        exit 1
#      fi
#      # --- end runfiles.sh initialization ---


# Check that we can find the bintools, otherwise we would see confusing errors.
which stat >&/dev/null || {
  echo >&2 "ERROR[runfiles.sh]: cannot locate GNU coreutils; check your PATH."
  echo >&2 "     Run the following on Linux/macOS:"
  echo >&2 "         export PATH=\"/bin:/usr/bin:\$PATH\""
  echo >&2 "     Run the following on Windows (adjust for your MSYS path):"
  echo >&2 "         set PATH=c:\\tools\\msys64\\usr\\bin;%PATH%"
  exit 1
}

case "$(uname -s | tr [:upper:] [:lower:])" in
msys*|mingw*|cygwin*)
  isabs_pattern="^[a-zA-Z]:[/\\]"  # matches an absolute Windows path
  ;;
*)
  isabs_pattern="^/.*"  # matches an absolute Unix path
  ;;
esac

# Print to stdout the runtime location of a data-dependency
# $1 is the the runfiles-relative path of the data-dependency.
# The function fails if $1 contains "..". If $1 is absolute, the function prints
# it as-is.
function rlocation() {
  if [[ "$1" =~ $isabs_pattern ]]; then
    echo $1
  elif [[ "$1" =~ \.\. ]]; then
    echo >&2 "ERROR: rlocation($1): contains uplevel references"
    exit 1
  else
    if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
      grep -m1 "^$1 " "${RUNFILES_MANIFEST_FILE}" | cut -d ' ' -f 2-
    else
      echo "${RUNFILES_DIR}/$1"
    fi
  fi
}
export -f rlocation

# Exports the environment variables that subprocesses may need to use runfiles.
# If a subprocess is a Bazel-built binary rule that also uses the runfiles
# libraries under @bazel_tools//tools/runfiles, then that binary needs these
# envvars in order to initialize its own runfiles library.
function runfiles_export_envvars() {
  if [[ -z "${RUNFILES_DIR:-}" ]]; then
    if [[ "${RUNFILES_MANIFEST_FILE:-}" =~ /MANIFEST$ ]]; then
      export RUNFILES_DIR="${RUNFILES_MANIFEST_FILE%/MANIFEST}"
    else
      export RUNFILES_DIR="${RUNFILES_MANIFEST_FILE%_manifest}"
    fi
  fi
  if [[ -z "${RUNFILES_MANIFEST_FILE:-}" && -n "${RUNFILES_DIR:-}" ]]; then
    export RUNFILES_MANIFEST_FILE=${RUNFILES_DIR}/MANIFEST
  fi
  export "RUNFILES_MANIFEST_FILE=${RUNFILES_MANIFEST_FILE:-}"
  export "RUNFILES_DIR=${RUNFILES_DIR:-}"
  export "JAVA_RUNFILES=${RUNFILES_DIR:-}"
}
export -f runfiles_export_envvars
