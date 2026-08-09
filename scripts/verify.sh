#!/usr/bin/env bash
# Checks the things an external system will reject us for. Nothing else.
#
# Deliberately does NOT re-assert the palette against a second copy of itself:
# editing manifest.json's colours IS the work, not a defect to guard against.
#
# No `set -e`: every check runs so the output lists all failures at once.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { if [ "$2" = "0" ]; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

echo "store limits"
rc=0
python3 - <<'PY' || rc=$?
import json, sys, os, struct
errs = []

# Chrome rejects the package outright for these.
m = json.load(open('manifest.json', encoding='utf-8'))
if m.get('default_locale') != 'en':
    errs.append(f"default_locale: expected 'en', got {m.get('default_locale')!r}")

for loc in ('en', 'pt_BR'):
    path = f'_locales/{loc}/messages.json'
    if not os.path.exists(path):
        errs.append(f'{path}: missing'); continue
    msgs = json.load(open(path, encoding='utf-8'))
    for key, limit in (('name', 75), ('description', 132)):
        text = msgs.get(key, {}).get('message')
        if not text:
            errs.append(f'{path}: {key} missing')
        elif len(text) > limit:
            errs.append(f'{path}: {key} is {len(text)} chars, limit {limit}')

# The store rejects a listing icon without its transparent padding.
path = 'store/icon-128.png'
if not os.path.exists(path):
    errs.append(f'{path}: missing')
else:
    head = open(path, 'rb').read(26)
    w, h = struct.unpack('>II', head[16:24])
    if (w, h) != (128, 128):
        errs.append(f'{path}: {w}x{h}, must be 128x128')
    if head[25] != 6:
        errs.append(f'{path}: colour type {head[25]}, must be 6 (RGBA) for the padded store icon')

if errs:
    print("\n".join('    ' + e for e in errs)); sys.exit(1)
PY
check "locale strings within Chrome's limits, store icon padded" "$rc"

echo "packaging"
rc=0
test -x scripts/package.sh || rc=$?
check "scripts/package.sh exists and is executable" "$rc"

exit $fail
