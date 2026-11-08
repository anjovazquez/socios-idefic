#!/usr/bin/env bash
exec "$(dirname "$0")/_flutter.sh" dart format --output=none --set-exit-if-changed lib test "$@"
