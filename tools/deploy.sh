#!/usr/bin/env bash
# Build and publish test builds to the Caddy site (https://139-162-152-247.sslip.io, password protected).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh
WWW=/var/www/emperors-gambit
rm -rf "${WWW:?}"/*
cp -r build/web/* "$WWW"/
cp build/android/emperors-gambit.apk "$WWW"/
echo "Deployed $(git rev-parse --short HEAD) -> $WWW"
