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
import json, re, sys, os, struct, zlib
errs = []

# Chrome rejects the package outright for these.
m = json.load(open('manifest.json', encoding='utf-8'))
if m.get('default_locale') != 'en':
    errs.append(f"default_locale: expected 'en', got {m.get('default_locale')!r}")

# Colour SHAPE, not colour values. Asserting the values would just compare
# manifest.json against a copy of itself; asserting the shape catches typos
# that make Chrome refuse to install the theme.
theme = m.get('theme')
if not isinstance(theme, dict) or not isinstance(theme.get('colors'), dict) or not theme['colors']:
    errs.append('manifest: theme.colors is missing or empty')
else:
    for key, val in theme['colors'].items():
        if not (isinstance(val, list) and len(val) == 3
                and all(isinstance(c, int) and not isinstance(c, bool) and 0 <= c <= 255
                        for c in val)):
            errs.append(f'theme.colors.{key}: {val!r} is not three integers 0-255')
    for name, path in theme.get('images', {}).items():
        if not os.path.exists(path):
            errs.append(f'theme.images.{name}: {path} does not exist')
        elif not path.lower().endswith('.png'):
            errs.append(f'theme.images.{name}: {path} is not a PNG; Chrome themes accept no other format')

# cog's pre_bump_hook rewrites the version with a sed that matches this exact
# shape. Reformat the key and the sed silently no-ops, tagging a release whose
# manifest still carries the old version.
if not re.search(r'^  "version": "[0-9]+(\.[0-9]+){0,3}",$',
                 open('manifest.json', encoding='utf-8').read(), re.M):
    errs.append('manifest: the version line no longer matches the pattern '
                'cog.toml\'s sed rewrites; the next release would not bump it')

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

# The store rejects a listing icon without its transparent padding. RGBA alone
# is not enough: a fully opaque RGBA file is exactly the icon they reject.
path = 'store/icon-128.png'
if not os.path.exists(path):
    errs.append(f'{path}: missing')
else:
    data = open(path, 'rb').read()
    pos, idat, ihdr = 8, b'', None
    while pos < len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        if tag == b'IHDR':
            ihdr = struct.unpack('>IIBBBBB', data[pos + 8:pos + 8 + length])
        elif tag == b'IDAT':
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    w, h, depth, ctype = ihdr[0], ihdr[1], ihdr[2], ihdr[3]
    if (w, h) != (128, 128):
        errs.append(f'{path}: {w}x{h}, must be 128x128')
    if ctype != 6:
        errs.append(f'{path}: colour type {ctype}, must be 6 (RGBA) for the padded store icon')
    elif depth != 8:
        errs.append(f'{path}: bit depth {depth}, expected 8')
    else:
        raw = zlib.decompress(idat)
        stride = w * 4
        if any(raw[y * (stride + 1)] != 0 for y in range(h)):
            errs.append(f'{path}: rows are not filter-0; re-export it so the padding can be checked')
        else:
            pad = (128 - 96) // 2
            border = []
            for y in range(h):
                row = raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)]
                if y < pad or y >= h - pad:
                    border += list(row[3::4])                       # whole row
                else:
                    border += list(row[3::4][:pad]) + list(row[3::4][-pad:])
            if any(border):
                errs.append(f'{path}: the {pad}px border is not transparent; '
                            'the store requires 96x96 artwork padded to 128x128')

if errs:
    print("\n".join('    ' + e for e in errs)); sys.exit(1)
PY
check "manifest valid for Chrome, locale strings within limits, store icon padded" "$rc"

echo "packaging"
rc=0
test -x scripts/package.sh || rc=$?
check "scripts/package.sh exists and is executable" "$rc"

exit $fail
