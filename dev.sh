#!/usr/bin/env bash
#
# Test the theme locally, no publishing needed.
#
#   ./dev.sh              # serves http://localhost:8080
#   PORT=9000 ./dev.sh    # a different port (RemNote wants 8080)
#
# Two things you can do with it:
#
#   1. Visual preview with every toggle:
#        http://localhost:8080/preview.html
#      (over http, not file://, so the phone iframe and the Google-Fonts extra
#      behave the way they will inside RemNote)
#
#   2. Live theme inside RemNote:
#        Settings -> Plugins -> Build -> "Develop from localhost"
#        enter http://localhost:8080/ and click Develop
#
# Every request is logged in this terminal, so you can see RemNote fetching
# manifest.json and theme.css.
set -euo pipefail

cd "$(dirname "$0")"

exec python3 dev_server.py --port "${PORT:-8080}"
