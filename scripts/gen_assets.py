#!/usr/bin/env python3
"""Generate icons and the store tile from the palette in manifest.json.

Standard library only, so no image library version can change the result.

The output is NOT byte-reproducible across machines. Python's zlib binds to the
system one, and Fedora ships zlib-ng while GitHub's runners ship stock zlib;
identical pixels compress to different bytes (379 vs 372 for the store icon).
CI therefore compares decoded PIXELS, not file bytes: `gen_assets.py --check`.
Never reintroduce a `git diff` check on these files.
"""
import json
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def png_bytes(width, height, rows, alpha=False):
    """Encode rows of (r, g, b) or (r, g, b, a) tuples as a PNG.

    alpha=True emits colour type 6 (RGBA), needed for the store icon, which the
    Web Store requires as 96x96 artwork inside 128x128 with transparent padding.
    """
    channels = 4 if alpha else 3
    raw = bytearray()
    for row in rows:
        raw.append(0)  # filter type 0, so output does not depend on a heuristic
        for px in row:
            raw += bytes(px[:channels])

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6 if alpha else 2, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', ihdr)
            + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
            + chunk(b'IEND', b''))


def render(width, height, colors):
    """Draw the theme's own surface ladder: frame, two tabs, toolbar, omnibox."""
    ground = tuple(colors['ntp_background'])
    tab = tuple(colors['background_tab'])
    bar = tuple(colors['toolbar'])
    accent = tuple(colors['omnibox_text'])

    px = [[ground] * width for _ in range(height)]

    def fill(x0, y0, x1, y1, color):
        for y in range(max(0, y0), min(height, y1)):
            row = px[y]
            for x in range(max(0, x0), min(width, x1)):
                row[x] = color

    pad = max(1, round(width * 0.12))
    inner = width - 2 * pad
    tab_top = round(height * 0.20)
    tab_bot = round(height * 0.42)
    bar_bot = round(height * 0.60)
    om_top = round(height * 0.70)
    om_bot = max(om_top + 1, round(height * 0.78))

    tab_w = max(1, round(inner * 0.44))
    gap = max(1, round(inner * 0.08))
    fill(pad, tab_top, pad + tab_w, tab_bot, tab)
    fill(pad + tab_w + gap, tab_top, pad + 2 * tab_w + gap, tab_bot, tab)
    fill(pad, tab_bot, pad + inner, bar_bot, bar)
    fill(pad, om_top, pad + inner, om_bot, accent)
    return px


def store_icon(colors, total=128, art=96):
    """128x128 with 96x96 artwork centred and the rest transparent.

    The Web Store requires that padding; a full-bleed icon is rejected or looks
    wrong against the store's own backgrounds. This is separate from the packaged
    images/icon-128.png, which is the extension icon and IS full bleed.
    """
    inner = render(art, art, colors)
    pad = (total - art) // 2
    blank = (0, 0, 0, 0)
    rows = []
    for y in range(total):
        if y < pad or y >= pad + art:
            rows.append([blank] * total)
            continue
        src = inner[y - pad]
        rows.append([blank] * pad + [(r, g, b, 255) for r, g, b in src]
                    + [blank] * (total - pad - art))
    return rows


def decode_png(path):
    """Decode one of our own PNGs to (width, height, colour_type, pixel bytes).

    Only handles what this script writes: depth 8, colour type 2 or 6, filter 0
    on every row, no interlacing. Anything else means the file was not produced
    here and should fail loudly rather than be silently accepted.
    """
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'{path}: not a PNG')
    pos, idat, ihdr = 8, b'', None
    while pos < len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        if tag == b'IHDR':
            ihdr = struct.unpack('>IIBBBBB', payload)
        elif tag == b'IDAT':
            idat += payload          # a different zlib may split these
        pos += 12 + length
    if ihdr is None:
        raise ValueError(f'{path}: no IHDR')
    w, h, depth, ctype, comp, filt, interlace = ihdr
    if (depth, comp, filt, interlace) != (8, 0, 0, 0) or ctype not in (2, 6):
        raise ValueError(f'{path}: unsupported PNG variant {ihdr}')
    raw = zlib.decompress(idat)
    stride = w * (4 if ctype == 6 else 3)
    out, p = bytearray(), 0
    for _ in range(h):
        if raw[p] != 0:
            raise ValueError(f'{path}: unexpected row filter {raw[p]}')
        p += 1
        out += raw[p:p + stride]
        p += stride
    return w, h, ctype, bytes(out)


def check(targets):
    """Compare committed files against a fresh render, by pixels."""
    problems = []
    for rel, expect in targets.items():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            problems.append(f'{rel}: missing'); continue
        try:
            w, h, ctype, pixels = decode_png(path)
        except ValueError as exc:
            problems.append(str(exc)); continue
        ew, eh, ectype, epixels = expect
        if (w, h, ctype) != (ew, eh, ectype):
            problems.append(
                f'{rel}: header is {w}x{h} type {ctype}, expected {ew}x{eh} type {ectype}')
        elif pixels != epixels:
            diff = sum(a != b for a, b in zip(pixels, epixels))
            problems.append(f'{rel}: {diff} of {len(epixels)} channel bytes differ from the palette')
    if problems:
        print('Committed assets do not match the palette in manifest.json:')
        for p in problems:
            print(f'  {p}')
        print('\nRun: python3 scripts/gen_assets.py && git add images store')
        return 1
    print(f'{len(targets)} generated assets match the palette (compared by pixel, not bytes)')
    return 0


def main():
    with open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8') as fh:
        colors = json.load(fh)['theme']['colors']

    targets = [(os.path.join('images', f'icon-{s}.png'), s, s)
               for s in (16, 32, 48, 128)]
    targets.append((os.path.join('store', 'tile-440x280.png'), 440, 280))

    if '--check' in sys.argv:
        expected = {}
        for rel, w, h in targets:
            rows = render(w, h, colors)
            expected[rel] = (w, h, 2, b''.join(bytes(px) for row in rows for px in row))
        rel = os.path.join('store', 'icon-128.png')
        rows = store_icon(colors)
        expected[rel] = (128, 128, 6, b''.join(bytes(px) for row in rows for px in row))
        sys.exit(check(expected))

    for rel, w, h in targets:
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = png_bytes(w, h, render(w, h, colors))
        with open(path, 'wb') as fh:
            fh.write(data)
        print(f'{rel}  {w}x{h}  {len(data)} bytes')

    rel = os.path.join('store', 'icon-128.png')
    path = os.path.join(ROOT, rel)
    data = png_bytes(128, 128, store_icon(colors), alpha=True)
    with open(path, 'wb') as fh:
        fh.write(data)
    print(f'{rel}  128x128 RGBA, 96x96 artwork + 16px padding  {len(data)} bytes')


if __name__ == '__main__':
    main()
