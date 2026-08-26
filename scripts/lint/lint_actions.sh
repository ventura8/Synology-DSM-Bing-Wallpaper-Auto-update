#!/usr/bin/env bash
set -euo pipefail

docker run --rm -v "$(pwd):/repo" -w /repo rhysd/actionlint:1.7.12
