#!/bin/sh

VERSION="$(
  /usr/bin/loki --version 2>/dev/null \
  | sed -n 's/^loki, version \([^ ]*\).*/\1/p'
)"

printf '%s\n' "$VERSION"
