#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${HOME}" /var/lib/gascity/city

if [ ! -f /var/lib/gascity/city/city.toml ]; then
  gc init /var/lib/gascity/city
fi

cd /var/lib/gascity/city
gc start
exec tail -f /dev/null
