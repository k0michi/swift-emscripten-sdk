# Swift SDK for Emscripten (unofficial)

Unofficial nightly builds of a Swift SDK for `wasm32-unknown-emscripten`.

swift.org snapshots ship a compiler that supports the Emscripten target, but
no Swift SDK for it. This repository builds one from each main development
snapshot and publishes it as a GitHub release.

This project is not affiliated with or endorsed by the Swift project.

## Usage

1. Install the toolchain from the same snapshot as the SDK. The stdlib's
   `.swiftmodule` files only work with the compiler that built them.
2. Install the SDK with the command in the release notes:

   ```
   swift sdk install <url> --checksum <checksum>
   ```

3. Build with it. Linking uses `emcc`, so install Emscripten as well, ideally
   the version named in the release notes:

   ```
   swift build --swift-sdk <tag>_wasm-emscripten
   ```

Foundation is not included yet.

## How it works

[`scripts/build.sh`](scripts/build.sh) builds the SDK on Linux:

1. Downloads the snapshot's Linux toolchain and uses it as the host compiler.
2. Installs Emscripten with emsdk.
3. Checks out the Swift sources at the snapshot tag with `update-checkout`.
4. Runs `build-script --build-emscripten-stdlib
   --build-runtime-with-host-compiler`. This builds the Emscripten sysroot and
   the stdlib, then calls swift-sdk-generator to make the bundle. It does not
   build LLVM or the Swift compiler.
5. Archives the bundle under the name `<tag>_wasm-emscripten.artifactbundle`,
   so it does not clash with the official WASI bundle (`<tag>_wasm`).

[The workflow](.github/workflows/build.yml) runs daily. When swift.org has
published a snapshot that has no release here, it builds the SDK and creates
a release named after the snapshot tag. Run it manually to build a specific
snapshot or to rebuild one.

To build locally (Ubuntu 24.04):

```
scripts/build.sh [snapshot-tag] [work-dir]
```
