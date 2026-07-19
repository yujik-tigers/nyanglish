#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/NyanglishDerivedDataLocal}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"

export DEVELOPER_DIR

xcodebuild \
  -project Nyanglish.xcodeproj \
  -scheme Nyanglish \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build
