#!/usr/bin/env bash
# Builds a Swift SDK for wasm32-unknown-emscripten from a swift.org main
# development snapshot, using that snapshot's own toolchain as the host
# compiler. Only the Emscripten stdlib is compiled; LLVM and the Swift
# compiler are not.
#
# Usage: scripts/build.sh [snapshot-tag] [work-dir]
#
# Linux (Ubuntu 24.04, x86_64 or aarch64) only. Writes the bundle to
# <work-dir>/dist.
#
# Environment:
#   EMSDK_VERSION  emsdk version to install (default: latest)
#   JOBS           parallel build jobs (default: all cores)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tag="${1:-$("$here/latest-snapshot.sh")}"
work="$(mkdir -p "${2:-$PWD/work}" && cd "${2:-$PWD/work}" && pwd)"
emsdk_version="${EMSDK_VERSION:-latest}"
jobs="${JOBS:-$(nproc)}"

echo "Snapshot: $tag"
echo "Work dir: $work"

# 1. The snapshot toolchain, used as the host compiler.
case "$(uname -m)" in
    x86_64) platform=ubuntu2404 suffix=ubuntu24.04 ;;
    aarch64) platform=ubuntu2404-aarch64 suffix=ubuntu24.04-aarch64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
toolchain="$work/toolchain"
if [[ ! -x "$toolchain/usr/bin/swiftc" ]]; then
    mkdir -p "$toolchain"
    curl -fsSL "https://download.swift.org/development/$platform/$tag/$tag-$suffix.tar.gz" |
        tar xz --strip-components=1 -C "$toolchain"
fi
export PATH="$toolchain/usr/bin:$PATH"
swiftc --version

# 2. Emscripten. embuilder from this checkout builds the sysroot.
emsdk="$work/emsdk"
if [[ ! -d "$emsdk" ]]; then
    git clone --depth 1 https://github.com/emscripten-core/emsdk "$emsdk"
fi
"$emsdk/emsdk" install "$emsdk_version"
"$emsdk/emsdk" activate "$emsdk_version"
emscripten="$emsdk/upstream/emscripten"
echo "Emscripten: $(cat "$emscripten/emscripten-version.txt")"

# 3. Sources at the snapshot tag. Repositories without the tag (such as
# swift-sdk-generator and its dependencies) fall back to their main branch.
source="$work/source"
if [[ ! -d "$source/swift" ]]; then
    git clone --depth 1 --branch "$tag" https://github.com/swiftlang/swift "$source/swift"
fi
# build-script runs swift-sdk-generator with SWIFTCI_USE_LOCAL_DEPS=1, so it
# and its dependencies resolve their dependencies from sibling checkouts.
needed=(
    swift llvm-project swift-syntax swift-experimental-string-processing
    swift-sdk-generator swift-argument-parser swift-asn1
    swift-async-algorithms swift-atomics swift-collections swift-crypto
    swift-log swift-nio swift-system
)
skip_args=()
while read -r repo; do
    skip_args+=(--skip-repository "$repo")
done < <(python3 - "$source/swift/utils/update_checkout/update-checkout-config.json" "${needed[@]}" <<'EOF'
import json, sys
repos = json.load(open(sys.argv[1]))["repos"]
print("\n".join(sorted(set(repos) - set(sys.argv[2:]))))
EOF
)
"$source/swift/utils/update-checkout" --clone --skip-history --skip-tags \
    --tag "$tag" --source-root "$source" "${skip_args[@]}"

# 4. The Emscripten stdlib and the Swift SDK bundle.
build="$work/build"
SWIFT_BUILD_ROOT="$build" TOOLCHAIN_VERSION="$tag" \
"$source/swift/utils/build-script" \
    --release \
    --jobs "$jobs" \
    --skip-early-swift-driver \
    --skip-build-cmark \
    --skip-build-llvm \
    --skip-build-swift \
    --build-runtime-with-host-compiler \
    --build-emscripten-stdlib \
    --skip-test-emscripten-stdlib \
    --emscripten-path "$emscripten"

# 5. Rename the bundle so it does not clash with the official WASI bundle,
# which uses the same "<tag>_wasm" name, and archive it.
bundle="$source/swift-sdk-generator/Bundles/${tag}_wasm.artifactbundle"
name="${tag}_wasm-emscripten.artifactbundle"
dist="$work/dist"
rm -rf "$dist" && mkdir -p "$dist"
cp -R "$bundle" "$dist/$name"
tar czf "$dist/$name.tar.gz" -C "$dist" "$name"
rm -rf "${dist:?}/$name"
# SwiftPM's --checksum is the SHA-256 of the archive.
(cd "$dist" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
tr -d '"' < "$emscripten/emscripten-version.txt" > "$dist/emscripten-version.txt"
ls -l "$dist"
