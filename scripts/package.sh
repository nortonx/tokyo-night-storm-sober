#!/usr/bin/env bash
# Build the Web Store package from an explicit allowlist.
# An allowlist is used rather than an exclude list so that a new stray file
# cannot silently end up in a published package.
set -euo pipefail
cd "$(dirname "$0")/.."

ALLOW=(manifest.json images _locales)

MANIFEST_VERSION=$(python3 -c "import json;print(json.load(open('manifest.json'))['version'])")
EXPECTED="${1:-$MANIFEST_VERSION}"

if [ "$EXPECTED" != "$MANIFEST_VERSION" ]; then
  echo "version mismatch: manifest says $MANIFEST_VERSION, expected $EXPECTED" >&2
  exit 1
fi

for entry in "${ALLOW[@]}"; do
  if [ ! -e "$entry" ]; then
    echo "missing required entry: $entry" >&2
    exit 1
  fi
done

OUT="dist/tokyo-night-storm-reading-${MANIFEST_VERSION}.zip"
mkdir -p dist
rm -f "$OUT"
zip -r -q -X "$OUT" "${ALLOW[@]}" -x '*.DS_Store'

echo "contents of $OUT:"
unzip -Z1 "$OUT" | sed 's/^/  /'

TOP=$(unzip -Z1 "$OUT" | cut -d/ -f1 | sort -u)
EXPECTED_TOP=$(printf '%s\n' "${ALLOW[@]}" | sort -u)
if [ "$TOP" != "$EXPECTED_TOP" ]; then
  echo "package contains unexpected top-level entries" >&2
  printf 'got:\n%s\nexpected:\n%s\n' "$TOP" "$EXPECTED_TOP" >&2
  exit 1
fi

echo "$OUT"
