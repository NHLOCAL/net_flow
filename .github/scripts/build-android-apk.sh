#!/usr/bin/env bash
set -euo pipefail

build_type="${1:?Expected debug or release}"
if [[ "$build_type" != "debug" && "$build_type" != "release" ]]; then
  echo "Invalid build type: $build_type" >&2
  exit 2
fi

# Android's SDK Manager can occasionally receive a corrupted CMake archive.
# Retry the entire build on transient downloads without bypassing Gradle or
# Flutter's dependency validation.
for attempt in 1 2 3; do
  echo "Building Android $build_type APK (attempt $attempt of 3)"
  if flutter build apk --"$build_type"; then
    exit 0
  fi
  if [[ "$attempt" == 3 ]]; then
    echo "::error::Android $build_type APK failed after 3 attempts"
    exit 1
  fi
  sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -n "$sdk_root" && -d "$sdk_root/cmake/3.22.1" ]]; then
    # A partially installed CMake package should not poison the next attempt.
    rm -rf "$sdk_root/cmake/3.22.1"
  fi
  sleep $((attempt * 5))
done
