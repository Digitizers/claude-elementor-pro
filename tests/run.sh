#!/usr/bin/env bash
# Run the kit's bats test suite. Uses a system `bats` if available, else
# vendors bats-core into tests/.bats (git-ignored). Usage: bash tests/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v bats >/dev/null 2>&1; then
  BATS=bats
else
  VENDOR="$HERE/.bats"
  if [ ! -x "$VENDOR/bin/bats" ]; then
    echo "bats not found — vendoring bats-core into $VENDOR ..."
    rm -rf "$VENDOR"
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$VENDOR" >/dev/null 2>&1
  fi
  BATS="$VENDOR/bin/bats"
fi

echo "Using bats: $BATS"
"$BATS" "$HERE"/*.bats
