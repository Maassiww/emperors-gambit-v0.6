#!/usr/bin/env bash
# Build and publish test builds to the Caddy site (http://<server>:8090, password protected).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh
WWW=/var/www/emperors-gambit
rm -rf "${WWW:?}"/*
cp -r build/web/* "$WWW"/
cp build/android/emperors-gambit.apk "$WWW"/
echo "Deployed $(git rev-parse --short HEAD) -> $WWW"
