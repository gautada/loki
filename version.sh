#!/bin/sh

VERSION="$(
  pme /usr/bin/loki --version 2>/dev/null \
  | sed -n 's/^promtail, version \([^ ]*\).*/\1/p'
)"

printf '%s\n' "$VERSION"
