# Tokyo Night Storm (Reading) Store Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the existing Chrome theme from a three-file working tree to a package that can be published and re-published to the Chrome Web Store from a git tag.

**Architecture:** `manifest.json` is the single source of truth for the palette. Generated assets read their colours from it, so the icon can never drift from the theme. Packaging uses an explicit allowlist. A verification script gates every change and is reused unchanged by CI.

**Tech Stack:** Chrome MV3 theme manifest, Python 3 standard library only (`json`, `zlib`, `struct`), bash, ImageMagick (one-off background transform only, never in CI), GitHub Actions, Chrome Web Store API v2.

## Global Constraints

- Theme images must be PNG. No WebP, no JPEG.
- Only keys present in Chromium's `kOverwritableColorTable` are valid in `theme.colors`.
- `name` max 75 characters. `description` max 132 characters, plain text, no HTML.
- `default_locale` is required whenever `_locales/` exists.
- Store name is exactly `Tokyo Night Storm (Reading)`.
- English description is exactly: `Tokyo Night Storm with contrast tuned for long reading sessions. Enkia's canonical palette. Mint address bar, red controls.`
- pt-BR description is exactly: `Tokyo Night Storm com contraste ajustado para longas sessões de leitura. Paleta canônica da Enkia. Endereço em verde menta.`
- All files UTF-8. Portuguese accents are required, not optional.
- Asset generation must use only the Python standard library. No Pillow, no ImageMagick, no network. CI regenerates assets and fails on any diff, so generation must be byte-deterministic across machines.
- The package contains exactly three entries: `manifest.json`, `images/`, `_locales/`. Nothing else, ever.
- The release workflow triggers only on `v*` tags. Never add a `pull_request` trigger.
- Work happens on branch `feat/store-release`, based on `a416be7`. Do not commit to `main`.
- Commit messages follow Conventional Commits. Never add an AI co-author trailer.

## File Structure

| path | responsibility | task |
|---|---|---|
| `manifest.json` | palette, i18n references, icon declarations | 1, 2, 4 |
| `scripts/verify.sh` | all invariants; run locally and by CI | 1 (created), extended 2, 4, 5 |
| `_locales/en/messages.json` | English name and description | 2 |
| `_locales/pt_BR/messages.json` | Portuguese name and description | 2 |
| `images/ntp_background.png` | new tab background, optimised | 3 |
| `scripts/gen_assets.py` | deterministic PNG generation from manifest colours | 4 |
| `images/icon-{16,32,48,128}.png` | generated, ships in package | 4 |
| `store/tile-440x280.png` | generated, listing only, never packaged | 4 |
| `scripts/package.sh` | allowlist ZIP build with version guard | 5 |
| `README.md` | attribution, WCAG decision, release checklist | 6 |
| `.github/workflows/release.yml` | tag-triggered upload and publish | 7 |

---

### Task 1: Palette correction and verification harness

Ten colour keys change. Eight are the hue correction, two are the accents. Every other key stays exactly as it is.

**Files:**
- Modify: `manifest.json` (`theme.colors`)
- Create: `scripts/verify.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/verify.sh`, an executable that exits 0 when all invariants hold and non-zero otherwise. Later tasks append checks to it. CI calls it as `./scripts/verify.sh`.

- [ ] **Step 1: Write the failing check**

Create `scripts/verify.sh`:

```bash
#!/usr/bin/env bash
# Deliberately no `set -e`: every check must run so the output lists all
# failures at once, rather than aborting at the first one.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { if [ "$2" = "0" ]; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

echo "palette"
rc=0
python3 - <<'PY' || rc=$?
import json, sys
c = json.load(open('manifest.json'))['theme']['colors']
expected = {
    'frame': [24, 27, 40],
    'omnibox_background': [24, 27, 40],
    'ntp_background': [24, 27, 40],
    'frame_inactive': [20, 22, 32],
    'frame_incognito': [20, 22, 32],
    'frame_incognito_inactive': [20, 22, 32],
    'background_tab_inactive': [20, 22, 32],
    'background_tab_incognito_inactive': [20, 22, 32],
    'omnibox_text': [115, 218, 202],
    'toolbar_button_icon': [247, 118, 142],
}
unchanged = {
    'background_tab': [31, 35, 53],
    'background_tab_incognito': [31, 35, 53],
    'toolbar': [36, 40, 59],
    'button_background': [41, 46, 66],
    'tab_text': [192, 202, 245],
    'toolbar_text': [192, 202, 245],
    'bookmark_text': [169, 177, 214],
    'ntp_text': [192, 202, 245],
    'ntp_link': [122, 162, 247],
    'ntp_header': [65, 72, 104],
}
bad = []
for k, v in {**expected, **unchanged}.items():
    if c.get(k) != v:
        bad.append(f"{k}: expected {v}, got {c.get(k)}")
if bad:
    print("\n".join("    " + b for b in bad)); sys.exit(1)
PY
check "10 corrected keys and 10 untouched keys match the spec" "$rc"

exit $fail
```

Then `chmod +x scripts/verify.sh`.

- [ ] **Step 2: Run it to confirm it fails**

Run: `./scripts/verify.sh`

Expected: FAIL, listing ten mismatches beginning with `frame: expected [24, 27, 40], got [26, 27, 38]`.

- [ ] **Step 3: Apply the ten colour changes**

Edit `manifest.json`, `theme.colors` only. Replace these ten values and touch nothing else:

```json
"frame": [24, 27, 40],
"frame_inactive": [20, 22, 32],
"frame_incognito": [20, 22, 32],
"frame_incognito_inactive": [20, 22, 32],
"background_tab_inactive": [20, 22, 32],
"background_tab_incognito_inactive": [20, 22, 32],
"omnibox_background": [24, 27, 40],
"ntp_background": [24, 27, 40],
"omnibox_text": [115, 218, 202],
"toolbar_button_icon": [247, 118, 142]
```

Reference, for reviewers: `#181b28`, `#141620`, `#73daca` (Storm `green1`), `#f7768e` (Storm `red`).

- [ ] **Step 4: Run it to confirm it passes**

Run: `./scripts/verify.sh`

Expected: `ok   10 corrected keys and 10 untouched keys match the spec`, exit 0.

- [ ] **Step 5: Confirm the JSON is still valid and no key was lost**

Run:

```bash
python3 -c "
import json
c = json.load(open('manifest.json'))['theme']['colors']
print(len(c), 'colour keys')
assert len(c) == 28, 'key count changed — a key was added or dropped'
print('ok')
"
```

Expected: `28 colour keys` then `ok`.

- [ ] **Step 6: Commit**

```bash
git add manifest.json scripts/verify.sh
git commit -m "fix(theme): unify surfaces on Storm hue and add accent colours

Eight surface keys carried Tokyo Night values at H235-240 while every
Storm surface sits at H229. Correct hue and saturation at unchanged
lightness, so all contrast ratios move by at most 0.02.

Set omnibox_text to Storm green1 and toolbar_button_icon to Storm red.
Chrome applies omnibox_text to the URL host only; the scheme and path
use a separately derived dimmed colour.

Add scripts/verify.sh to hold the palette invariants."
```

---

### Task 2: Internationalisation

**Files:**
- Create: `_locales/en/messages.json`
- Create: `_locales/pt_BR/messages.json`
- Modify: `manifest.json` (`name`, `description`, add `default_locale`)
- Modify: `scripts/verify.sh`

**Interfaces:**
- Consumes: `scripts/verify.sh` from Task 1.
- Produces: message keys `name` and `description`, referenced from the manifest as `__MSG_name__` and `__MSG_description__`.

- [ ] **Step 1: Write the failing check**

Append to `scripts/verify.sh`, immediately before the final `exit $fail`:

```bash
echo "i18n"
rc=0
python3 - <<'PY' || rc=$?
import json, sys, os
errs = []
m = json.load(open('manifest.json'))
if m.get('default_locale') != 'en':
    errs.append(f"default_locale: expected 'en', got {m.get('default_locale')!r}")
if m.get('name') != '__MSG_name__':
    errs.append(f"name: expected '__MSG_name__', got {m.get('name')!r}")
if m.get('description') != '__MSG_description__':
    errs.append(f"description: expected '__MSG_description__', got {m.get('description')!r}")

expected = {
    'en': {
        'name': 'Tokyo Night Storm (Reading)',
        'description': "Tokyo Night Storm with contrast tuned for long reading sessions. Enkia's canonical palette. Mint address bar, red controls.",
    },
    'pt_BR': {
        'name': 'Tokyo Night Storm (Reading)',
        'description': 'Tokyo Night Storm com contraste ajustado para longas sessões de leitura. Paleta canônica da Enkia. Endereço em verde menta.',
    },
}
for loc, want in expected.items():
    path = f'_locales/{loc}/messages.json'
    if not os.path.exists(path):
        errs.append(f'{path}: missing'); continue
    with open(path, encoding='utf-8') as fh:
        got = json.load(fh)
    for key, text in want.items():
        actual = got.get(key, {}).get('message')
        if actual != text:
            errs.append(f'{path}: {key} mismatch')
        limit = 75 if key == 'name' else 132
        if actual and len(actual) > limit:
            errs.append(f'{path}: {key} is {len(actual)} chars, limit {limit}')
if errs:
    print("\n".join('    ' + e for e in errs)); sys.exit(1)
PY
check "locales present, manifest uses __MSG__ refs, lengths within limits" "$rc"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./scripts/verify.sh`

Expected: palette check passes; i18n check FAILs with `default_locale: expected 'en', got None` and both `_locales/...: missing`.

- [ ] **Step 3: Create the English messages file**

Create `_locales/en/messages.json`:

```json
{
  "name": {
    "message": "Tokyo Night Storm (Reading)",
    "description": "Extension name shown in the Web Store and chrome://extensions."
  },
  "description": {
    "message": "Tokyo Night Storm with contrast tuned for long reading sessions. Enkia's canonical palette. Mint address bar, red controls.",
    "description": "Short store summary, 132 character limit."
  }
}
```

- [ ] **Step 4: Create the Portuguese messages file**

Create `_locales/pt_BR/messages.json`. The accents are required:

```json
{
  "name": {
    "message": "Tokyo Night Storm (Reading)",
    "description": "Nome da extensão exibido na Web Store e em chrome://extensions."
  },
  "description": {
    "message": "Tokyo Night Storm com contraste ajustado para longas sessões de leitura. Paleta canônica da Enkia. Endereço em verde menta.",
    "description": "Resumo curto da loja, limite de 132 caracteres."
  }
}
```

- [ ] **Step 5: Point the manifest at the message keys**

In `manifest.json`, replace the `name` and `description` values and add `default_locale` directly after `manifest_version`:

```json
"manifest_version": 3,
"default_locale": "en",
"name": "__MSG_name__",
"version": "1.0.0",
"description": "__MSG_description__",
```

- [ ] **Step 6: Run it to confirm it passes**

Run: `./scripts/verify.sh`

Expected: both checks `ok`, exit 0.

- [ ] **Step 7: Confirm the accents survived the write**

Run:

```bash
python3 -c "
import json
d = json.load(open('_locales/pt_BR/messages.json', encoding='utf-8'))
t = d['description']['message']
assert 'sessões' in t and 'canônica' in t and 'Endereço' in t, 'accents lost'
print('accents ok,', len(t), 'chars')
"
```

Expected: `accents ok, 123 chars`.

- [ ] **Step 8: Commit**

```bash
git add manifest.json _locales scripts/verify.sh
git commit -m "feat(i18n): localise name and description in en and pt_BR

Add _locales with default_locale en, so the Web Store shows Portuguese
to pt-BR users and English to everyone else.

Restore the accents that were stripped from the original description;
manifest and message files are UTF-8."
```

---

### Task 3: Optimise the new tab background

A one-off transform of existing artwork, not a repeatable build step, so it gets no script. The original stays recoverable from git history at `cfdccff`.

**Files:**
- Modify: `images/ntp_background.png`

**Interfaces:**
- Consumes: nothing.
- Produces: `images/ntp_background.png`, still 2560x1440 PNG, under 20 KB.

- [ ] **Step 1: Keep a copy of the original for comparison**

Run:

```bash
cp images/ntp_background.png /tmp/ntp_original.png
stat -c%s /tmp/ntp_original.png
```

Expected: `672827`.

- [ ] **Step 2: Write the failing check**

Run:

```bash
test "$(stat -c%s images/ntp_background.png)" -lt 20000 && echo PASS || echo FAIL
```

Expected: `FAIL`. The file is 672827 bytes.

- [ ] **Step 3: Collapse each row to its mean and restore width**

Run:

```bash
magick images/ntp_background.png \
  -resize 1x1440! -resize 2560x1440! \
  -strip -define png:compression-level=9 \
  /tmp/ntp_optimised.png
mv /tmp/ntp_optimised.png images/ntp_background.png
```

Write to a temporary path and move, never read and write the same file in one `magick` invocation.

- [ ] **Step 4: Run the size check again**

Run:

```bash
test "$(stat -c%s images/ntp_background.png)" -lt 20000 && echo PASS || echo FAIL
stat -c%s images/ntp_background.png
```

Expected: `PASS`, then roughly `5900`.

- [ ] **Step 5: Verify dimensions, format, and perceptual fidelity**

Run:

```bash
magick identify -format "%wx%h %m depth=%[depth]\n" images/ntp_background.png
magick /tmp/ntp_original.png images/ntp_background.png \
  -compose difference -composite \
  -format "max=%[fx:maxima*255] mean=%[fx:mean*255]\n" info:
```

Expected: `2560x1440 PNG depth=8`, and `max=5 mean=0.50...`. A mean above 1.0 means the wrong transform ran; revert with `git checkout images/ntp_background.png` and redo Step 3.

- [ ] **Step 6: Commit**

```bash
git add images/ntp_background.png
git commit -m "perf(assets): shrink new tab background from 658 KB to 5.8 KB

Collapse each row to its mean and restore width. The vertical profile is
kept at full 1440-row resolution; only sub-perceptual horizontal
variation and dither noise are discarded.

Mean error 0.50/255, maximum 5/255. Verified indistinguishable at normal
contrast. The original remains in history at cfdccff."
```

---

### Task 4: Generate icons and the store tile

**Files:**
- Create: `scripts/gen_assets.py`
- Create: `images/icon-16.png`, `images/icon-32.png`, `images/icon-48.png`, `images/icon-128.png`
- Create: `store/tile-440x280.png`
- Modify: `manifest.json` (add `icons`)
- Modify: `scripts/verify.sh`

**Interfaces:**
- Consumes: `theme.colors` from `manifest.json`; `scripts/verify.sh` from Task 1.
- Produces: `scripts/gen_assets.py`, runnable as `python3 scripts/gen_assets.py`, writing five PNGs and printing one line per file. Byte-deterministic: running it twice produces identical bytes.

- [ ] **Step 1: Write the failing check**

Append to `scripts/verify.sh`, before the final `exit $fail`:

```bash
echo "generated assets"
rc=0
python3 - <<'PY' || rc=$?
import json, sys, os, struct
errs = []
m = json.load(open('manifest.json'))
icons = m.get('icons', {})
for size in ('16', '32', '48', '128'):
    if icons.get(size) != f'images/icon-{size}.png':
        errs.append(f'manifest icons[{size}] wrong or missing')
wanted = [(f'images/icon-{s}.png', int(s), int(s)) for s in ('16','32','48','128')]
wanted.append(('store/tile-440x280.png', 440, 280))
for path, w, h in wanted:
    if not os.path.exists(path):
        errs.append(f'{path}: missing'); continue
    with open(path, 'rb') as fh:
        head = fh.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        errs.append(f'{path}: not a PNG'); continue
    gw, gh = struct.unpack('>II', head[16:24])
    if (gw, gh) != (w, h):
        errs.append(f'{path}: expected {w}x{h}, got {gw}x{gh}')
if errs:
    print("\n".join('    ' + e for e in errs)); sys.exit(1)
PY
check "icons and tile exist at correct dimensions, manifest declares them" "$rc"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./scripts/verify.sh`

Expected: first two checks `ok`; asset check FAILs with four `manifest icons[..] wrong or missing` and five `missing` lines.

- [ ] **Step 3: Write the generator**

Create `scripts/gen_assets.py`:

```python
#!/usr/bin/env python3
"""Generate icons and the store tile from the palette in manifest.json.

Standard library only and byte-deterministic: CI regenerates these and fails
on any diff, so output must not vary with the machine or an image library
version.
"""
import json
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def png_bytes(width, height, rows):
    """Encode rows of (r, g, b) tuples as a truecolour PNG."""
    raw = bytearray()
    for row in rows:
        raw.append(0)  # filter type 0, so output does not depend on a heuristic
        for r, g, b in row:
            raw += bytes((r, g, b))

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
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


def main():
    with open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8') as fh:
        colors = json.load(fh)['theme']['colors']

    targets = [(os.path.join('images', f'icon-{s}.png'), s, s)
               for s in (16, 32, 48, 128)]
    targets.append((os.path.join('store', 'tile-440x280.png'), 440, 280))

    for rel, w, h in targets:
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = png_bytes(w, h, render(w, h, colors))
        with open(path, 'wb') as fh:
            fh.write(data)
        print(f'{rel}  {w}x{h}  {len(data)} bytes')


if __name__ == '__main__':
    main()
```

- [ ] **Step 4: Run the generator**

Run: `python3 scripts/gen_assets.py`

Expected: five lines, for example `images/icon-16.png  16x16  ... bytes` through `store/tile-440x280.png  440x280  ... bytes`.

- [ ] **Step 5: Prove the output is deterministic**

This is the property CI depends on. Run:

```bash
md5sum images/icon-128.png store/tile-440x280.png > /tmp/assets.md5
python3 scripts/gen_assets.py >/dev/null
md5sum -c /tmp/assets.md5
```

Expected: both lines report `OK`. If they differ, generation is not deterministic and CI will fail intermittently; fix before continuing.

- [ ] **Step 6: Declare the icons in the manifest**

In `manifest.json`, add after `description`:

```json
"icons": {
  "16": "images/icon-16.png",
  "32": "images/icon-32.png",
  "48": "images/icon-48.png",
  "128": "images/icon-128.png"
},
```

- [ ] **Step 7: Run verification**

Run: `./scripts/verify.sh`

Expected: all three checks `ok`, exit 0.

- [ ] **Step 8: Look at the 128px icon**

Open `images/icon-128.png`. It should read as two tabs above a toolbar band with a mint bar beneath, on the dark ground. If it reads as noise at 16px, adjust the fractions in `render()` and rerun Steps 4 to 7.

- [ ] **Step 9: Commit**

```bash
git add scripts/gen_assets.py images/icon-*.png store/tile-440x280.png manifest.json scripts/verify.sh
git commit -m "feat(assets): generate icons and store tile from the palette

Read theme.colors from manifest.json and draw the theme's own surface
ladder, so the icon cannot drift from the palette.

Standard library only and byte-deterministic, because CI regenerates
these assets and fails on any diff. An image library version difference
would otherwise break the build."
```

---

### Task 5: Packaging

**Files:**
- Create: `scripts/package.sh`
- Modify: `scripts/verify.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: `scripts/package.sh`, which accepts an optional version argument and writes `dist/tokyo-night-storm-reading-<version>.zip`. Called by CI as `./scripts/package.sh "$VERSION"`.

- [ ] **Step 1: Write the failing check**

Append to `scripts/verify.sh`, before the final `exit $fail`:

```bash
echo "packaging"
rc=0
test -x scripts/package.sh || rc=$?
check "scripts/package.sh exists and is executable" "$rc"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./scripts/verify.sh`

Expected: earlier checks `ok`; `FAIL scripts/package.sh exists and is executable`.

- [ ] **Step 3: Write the packaging script**

Create `scripts/package.sh`:

```bash
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
```

Then `chmod +x scripts/package.sh`.

- [ ] **Step 4: Run verification and the script**

Run:

```bash
./scripts/verify.sh
./scripts/package.sh
```

Expected: verification all `ok`. Packaging lists the archive contents, every path beginning `manifest.json`, `images/`, or `_locales/`, and prints `dist/tokyo-night-storm-reading-1.0.0.zip`.

- [ ] **Step 5: Prove the version guard works**

Run: `./scripts/package.sh 9.9.9`

Expected: exit 1 with `version mismatch: manifest says 1.0.0, expected 9.9.9`.

- [ ] **Step 6: Prove the allowlist rejects strays**

Run:

```bash
touch images/scratch.tmp
./scripts/package.sh >/dev/null
unzip -Z1 dist/tokyo-night-storm-reading-1.0.0.zip | grep scratch.tmp && echo "LEAKED" || echo "not present"
rm -f images/scratch.tmp dist/tokyo-night-storm-reading-1.0.0.zip
```

Expected: `images/scratch.tmp` **is** listed, printing `LEAKED`. This is correct and worth understanding: the allowlist protects the repository *root*, not the interior of allowed directories. Anything inside `images/` ships. `.gitignore` keeps such files out of the repo; the allowlist keeps new root-level files out of the package. Do not attempt to filter inside `images/`.

- [ ] **Step 7: Commit**

```bash
git add scripts/package.sh scripts/verify.sh
git commit -m "build: add allowlist packaging script with version guard

Package from an explicit allowlist of manifest.json, images, and
_locales, so a new root-level file cannot leak into a published
package. Fail when the manifest version does not match the expected
version, which CI derives from the git tag."
```

---

### Task 6: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the attribution required by MIT for a derived work, plus the manual release checklist the pipeline cannot perform.

- [ ] **Step 1: Write the README**

Create `README.md`:

````markdown
# Tokyo Night Storm (Reading)

A Chrome theme. Tokyo Night Storm with contrast tuned for long reading sessions.

## Attribution

Tokyo Night is the work of [Enkia](https://github.com/enkia/tokyo-night-vscode-theme),
distributed under the MIT License. This theme is a derived work: the palette
follows the canonical Storm variant, and the colour values here are Enkia's.

This repository is separately MIT licensed; see `LICENSE`.

## Palette decisions

Surface colours follow Storm exactly. Two accents differ from a plain port:

| key | value | effect |
|---|---|---|
| `omnibox_text` | `#73daca` | Chrome applies this to the URL host only. The scheme and path use a separately derived dimmed colour that themes cannot set. |
| `toolbar_button_icon` | `#f7768e` | Toolbar buttons outside the address bar. The bookmark star sits inside it and follows `omnibox_text`. |

A typed search query has no host to isolate, so it renders entirely in the
accent colour. There is no key that separates URL text from query text.

### Contrast

All text pairs pass WCAG AA; the weakest is 4.78:1. Surface-to-surface
separation is deliberately below WCAG 1.4.11: `toolbar` against
`background_tab` is 1.07:1. Reaching 3:1 would require lightness 52%
(`#6772a2`), a mid-grey tab strip that is not Tokyo Night. Tab identity is
carried by label contrast instead, active `#c0caf5` at 9.02:1 against idle
`#9aa5ce` at 6.41:1. This is a considered decision, not an oversight.

## Development

```bash
./scripts/verify.sh          # all invariants; CI runs exactly this
python3 scripts/gen_assets.py # regenerate icons and tile from manifest colours
./scripts/package.sh          # build dist/tokyo-night-storm-reading-<version>.zip
```

Load unpacked from the repository root via `chrome://extensions`. Chrome writes
a `Cached Theme.pak` there when it does; it is git-ignored and safe to delete.

## Releasing

Tagging `v<version>` builds and publishes the package. The API moves the
package only. These are Dashboard-only and must be done by hand:

- [ ] Detailed description, English
- [ ] Detailed description, Portuguese, via the locale dropdown
- [ ] Screenshots, 1280x800, up to five
- [ ] Store icon, 128x128, and the 440x280 tile from `store/`
- [ ] Category and language
- [ ] Privacy tab: no permissions, no data collected

Screenshots cannot be automated. Browser chrome is not capturable by DevTools
or Playwright, which see page content only. Take them with an OS screenshot.
````

- [ ] **Step 2: Check the code fences survived**

The Development section nests a fenced block inside the document, so the file uses four-backtick fences where needed. Run:

```bash
grep -c '```' README.md
python3 -c "
import re
t = open('README.md', encoding='utf-8').read()
assert t.count('```bash') == 1, 'expected exactly one bash fence'
assert 'enkia' in t.lower(), 'attribution missing'
print('ok')
"
```

Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with attribution and release checklist

Record Enkia's copyright as MIT requires for a derived work, document the
deliberate WCAG 1.4.11 decision on surface separation, and list the
Dashboard-only release steps the API cannot perform."
```

---

### Task 7: Release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `scripts/verify.sh`, `scripts/gen_assets.py`, `scripts/package.sh`.
- Produces: a workflow with two entry points. `push` on `v*` tags runs verify through publish. `workflow_dispatch` runs verify through upload and stops before publishing.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/release.yml`:

```yaml
name: release

# Tags only. Never add pull_request: a fork PR would expose credentials on
# this public repository.
on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      publish:
        description: 'Publish to the store as well as uploading'
        type: boolean
        default: false

permissions:
  contents: write   # attach the ZIP to the release
  id-token: write   # mint the federated token

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Derive version
        id: v
        run: |
          if [ "${GITHUB_REF_TYPE}" = "tag" ]; then
            echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"
          else
            echo "version=$(python3 -c "import json;print(json.load(open('manifest.json'))['version'])")" >> "$GITHUB_OUTPUT"
          fi

      - name: Verify invariants
        run: ./scripts/verify.sh

      - name: Assets must match the committed palette
        run: |
          python3 scripts/gen_assets.py
          if ! git diff --quiet -- images store; then
            echo "Generated assets differ from what is committed." >&2
            echo "Run: python3 scripts/gen_assets.py && git add images store" >&2
            git --no-pager diff --stat -- images store >&2
            exit 1
          fi

      - name: Build package
        run: ./scripts/package.sh "${{ steps.v.outputs.version }}"

      - uses: google-github-actions/auth@v2
        with:
          project_id: ${{ vars.GCP_PROJECT_ID }}
          workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Upload to the Chrome Web Store
        env:
          PUBLISHER: ${{ secrets.CWS_PUBLISHER_ID }}
          ITEM: ${{ secrets.CWS_EXTENSION_ID }}
        run: |
          TOKEN=$(gcloud auth print-access-token \
            --scopes="https://www.googleapis.com/auth/chromewebstore")
          ZIP="dist/tokyo-night-storm-reading-${{ steps.v.outputs.version }}.zip"
          curl --fail-with-body -sS \
            -H "Authorization: Bearer $TOKEN" \
            -X POST -T "$ZIP" \
            "https://chromewebstore.googleapis.com/upload/v2/publishers/$PUBLISHER/items/$ITEM:upload"

      - name: Publish
        if: github.ref_type == 'tag' || inputs.publish
        env:
          PUBLISHER: ${{ secrets.CWS_PUBLISHER_ID }}
          ITEM: ${{ secrets.CWS_EXTENSION_ID }}
        run: |
          TOKEN=$(gcloud auth print-access-token \
            --scopes="https://www.googleapis.com/auth/chromewebstore")
          curl --fail-with-body -sS \
            -H "Authorization: Bearer $TOKEN" \
            -X POST -H "Content-Length: 0" \
            "https://chromewebstore.googleapis.com/v2/publishers/$PUBLISHER/items/$ITEM:publish"

      - name: Attach the package to the release
        if: github.ref_type == 'tag'
        uses: softprops/action-gh-release@v2
        with:
          files: dist/tokyo-night-storm-reading-${{ steps.v.outputs.version }}.zip
```

- [ ] **Step 2: Check the YAML parses**

Run:

```bash
python3 -c "
import sys
try:
    import yaml
except ImportError:
    sys.exit('pyyaml not installed; skip and rely on the Actions linter')
d = yaml.safe_load(open('.github/workflows/release.yml'))
assert 'pull_request' not in d[True], 'pull_request trigger present — forbidden'
print('triggers:', list(d[True]))
print('steps:', len(d['jobs']['release']['steps']))
"
```

Expected: `triggers: ['push', 'workflow_dispatch']` and `steps: 9`. If `pyyaml` is absent the check exits with a message; that is acceptable, GitHub will validate on push.

- [ ] **Step 3: Confirm no pull_request trigger, whatever the parser said**

Run: `grep -n "pull_request" .github/workflows/release.yml || echo "absent, correct"`

Expected: `absent, correct`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: publish to the Chrome Web Store on v* tags

Verify invariants, fail if generated assets drift from the committed
palette, build from the allowlist, then upload and publish through the
Chrome Web Store API v2.

Authenticate with Workload Identity Federation so no long-lived
credential is stored. Tags and manual dispatch only; a pull_request
trigger would expose credentials to fork PRs on this public repository."
```

---

## Verification after all tasks

- [ ] `./scripts/verify.sh` exits 0 with every check `ok`
- [ ] `./scripts/package.sh` produces a ZIP whose only top-level entries are `manifest.json`, `images`, `_locales`
- [ ] `python3 scripts/gen_assets.py && git diff --quiet -- images store` leaves no diff
- [ ] Loading the repository unpacked in Chrome shows a mint domain in the address bar and red toolbar icons
- [ ] `git log --oneline a416be7..HEAD` lists seven commits on `feat/store-release`

## Deferred to the operator

These are in the spec but cannot be done from the repository:

- Service account creation and dashboard authorisation
- The WIF provider, which must pin `assertion.repository == 'nortonx/tokyo-night-storm-sober'`
- Repository secrets and variables: `GCP_WIF_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `CWS_PUBLISHER_ID`, `CWS_EXTENSION_ID`, `GCP_PROJECT_ID`
- The first manual upload that creates the store item and yields its ID
- Screenshots and the per-locale long descriptions
