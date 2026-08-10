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

# Web Store hard limits, listed in README.md's Platform constraints table.
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


# A PNG is an 8-byte signature then chunks of length(4) + tag(4) + data + crc(4).
# Only IHDR (geometry) and IDAT (pixels) matter here. CRCs go unchecked: a
# corrupt file fails the geometry or padding check below, which is the outcome
# worth reporting.
def read_png(path):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        return None, b''
    pos, ihdr, idat = 8, None, b''
    while pos + 8 <= len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        if tag == b'IHDR' and length == 13:
            ihdr = struct.unpack('>IIBBBBB', data[pos + 8:pos + 21])
        elif tag == b'IDAT':
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    return ihdr, idat


# Undo PNG's per-row filters (spec section 9.2). Every image editor picks these
# adaptively per row, so reading the rows as raw bytes would reject any icon
# that had been legitimately re-exported.
def unfilter(raw, w, h, bpp):
    stride, out, prev, pos = w * bpp, bytearray(), bytes(w * bpp), 0
    for _ in range(h):
        f, line = raw[pos], bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if f:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                if f == 1:
                    line[i] = (line[i] + a) & 0xff
                elif f == 2:
                    line[i] = (line[i] + b) & 0xff
                elif f == 3:
                    line[i] = (line[i] + ((a + b) >> 1)) & 0xff
                elif f == 4:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xff
        out += line
        prev = bytes(line)
    return bytes(out)


# Everything something else reads at a fixed size. A wrong-sized icon or tile is
# rejected at upload, which is a slow and manual way to find out.
sized = [(p, int(s), int(s))
         for s, p in sorted(m.get('icons', {}).items(), key=lambda kv: int(kv[0]))]
sized += [('store/icon-128.png', 128, 128), ('store/tile-440x280.png', 440, 280)]

store_icon = None
for path, want_w, want_h in sized:
    if not os.path.exists(path):
        errs.append(f'{path}: missing')
        continue
    ihdr, idat = read_png(path)
    if ihdr is None:
        errs.append(f'{path}: not a PNG')
        continue
    if (ihdr[0], ihdr[1]) != (want_w, want_h):
        errs.append(f'{path}: {ihdr[0]}x{ihdr[1]}, must be {want_w}x{want_h}')
    if path == 'store/icon-128.png':
        store_icon = (ihdr, idat)

# The store rejects a listing icon without its transparent padding. RGBA alone
# is not enough: a fully opaque RGBA file is exactly the icon they reject.
if store_icon:
    (w, h, depth, ctype, _, _, interlace), idat = store_icon
    if ctype != 6:
        errs.append(f'store/icon-128.png: colour type {ctype}, must be 6 (RGBA) for the padded store icon')
    elif depth != 8:
        # The padding check reads one byte per sample. Supporting 16-bit would
        # mean a second stride calculation for a file we always export as 8.
        errs.append(f'store/icon-128.png: bit depth {depth}, expected 8')
    elif interlace:
        errs.append('store/icon-128.png: interlaced; re-export it without Adam7 interlacing')
    else:
        raw = b''
        try:
            raw = unfilter(zlib.decompress(idat), w, h, 4)
        except (zlib.error, IndexError):
            errs.append('store/icon-128.png: the pixel data does not decode; the file is corrupt')
        if len(raw) == w * h * 4:
            pad = (128 - 96) // 2                  # 96x96 of artwork centred in 128x128
            border = []
            for y in range(h):
                alpha = raw[y * w * 4 + 3:(y + 1) * w * 4:4]
                border += (list(alpha) if y < pad or y >= h - pad
                           else list(alpha[:pad]) + list(alpha[-pad:]))
            if any(border):
                errs.append(f'store/icon-128.png: the {pad}px border is not transparent; '
                            'the store requires 96x96 artwork padded to 128x128')

if errs:
    print("\n".join('    ' + e for e in errs)); sys.exit(1)
PY
check "manifest valid for Chrome, locale strings within limits, images correctly sized" "$rc"

echo "packaging"
rc=0
test -x scripts/package.sh || rc=$?
check "scripts/package.sh exists and is executable" "$rc"

exit $fail
