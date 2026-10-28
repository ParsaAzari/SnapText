#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="/tmp/snaptext_acceptance_runner"

swiftc -o "$RUNNER" \
    "$PROJECT_DIR/Sources/BidiReconstructor.swift" \
    "$PROJECT_DIR/Sources/PersianNormalizer.swift" \
    "$PROJECT_DIR/Tests/PersianNormalizerTests.swift"

"$RUNNER"
rm -f "$RUNNER"
