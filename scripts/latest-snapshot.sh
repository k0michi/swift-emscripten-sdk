#!/usr/bin/env bash
# Prints the tag of the newest swift.org main development snapshot that has
# a Linux toolchain, e.g. swift-DEVELOPMENT-SNAPSHOT-2026-10-17-a.
set -euo pipefail

curl -fsSL https://download.swift.org/development/ubuntu2404/latest-build.yml |
    sed -n 's/^dir: *//p'
