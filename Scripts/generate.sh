#!/usr/bin/env bash
# NextGame.xcodeproj is generated from project.yml and not checked in.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
