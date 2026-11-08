#!/usr/bin/env bash
exec "$(dirname "$0")/_flutter.sh" flutter pub get "$@"
