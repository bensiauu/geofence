#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Building Go custom-runtime binary..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap .

echo "→ Packaging…"
zip -j geo.zip bootstrap
rm bootstrap
