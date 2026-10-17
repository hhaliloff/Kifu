#!/bin/bash
set -euo pipefail

# Xcode build phases do not inherit the interactive shell's Homebrew PATH.
export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin"
for tool in cmake ninja; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "error: ${tool} is required to build KataGo. Install CMake and Ninja, then retry the build." >&2
    exit 1
  fi
done

source_root="${SRCROOT:?Xcode must define SRCROOT}"
sdk_root="${SDKROOT:?Xcode must define SDKROOT}"
platform="${PLATFORM_NAME:?Xcode must define PLATFORM_NAME}"
deployment_target="${IPHONEOS_DEPLOYMENT_TARGET:-17.0}"
derived_file_dir="${DERIVED_FILE_DIR:?Xcode must define DERIVED_FILE_DIR}"
engine_source="${source_root}/Vendor/KataGo/cpp"
engine_build_root="${derived_file_dir}/KataGoBuild/${platform}"
engine_output_dir="${derived_file_dir}/KataGo"
module_cache_dir="${derived_file_dir}/KataGoModuleCache"
mkdir -p "${engine_output_dir}" "${module_cache_dir}"

export CLANG_MODULE_CACHE_PATH="${module_cache_dir}"
export SWIFT_MODULECACHE_PATH="${module_cache_dir}"

archives=()
for arch in ${ARCHS:?Xcode must define ARCHS}; do
  build_dir="${engine_build_root}/${arch}"
  swift_target="${arch}-apple-ios${deployment_target}"
  if [[ "${platform}" == "iphonesimulator" ]]; then
    swift_target="${swift_target}-simulator"
  fi

  cmake -S "${engine_source}" -B "${build_dir}" -G Ninja \
    -DUSE_BACKEND=METAL \
    -DKATAGO_IOS_APP=ON \
    -DNO_GIT_REVISION=1 \
    -DBUILD_DISTRIBUTED=0 \
    -DUSE_TCMALLOC=0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="${sdk_root}" \
    -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
    "-DCMAKE_Swift_FLAGS=-target ${swift_target}"
  cmake --build "${build_dir}" --target katago --parallel "${KATAGO_BUILD_JOBS:-3}"
  combined_archive="${build_dir}/libkatago-combined.a"
  xcrun libtool -static -o "${combined_archive}" \
    "${build_dir}/libkatago.a" "${build_dir}/libKataGoSwift.a"
  archives+=("${combined_archive}")
done

xcrun lipo -create "${archives[@]}" -output "${engine_output_dir}/libkatago.a"
