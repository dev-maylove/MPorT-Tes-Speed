#!/usr/bin/env bash
# Fast local analysis: lib/ only, infos not fatal.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze --no-fatal-infos lib
