#!/usr/bin/env bash
# Mutation tests for scripts/verify.sh.
#
# Each case breaks exactly one invariant in a throwaway copy of the tree and
# asserts verify.sh both fails AND names the right reason. A check that has
# silently stopped checking is indistinguishable from a passing build, which is
# how the colour validation was lost once already.
#
# mutate_* cases must make verify.sh fail. tweak_* cases change the tree in a
# way it must still accept, which is the only way to catch a check that rejects
# valid input.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
pass=0
fail=0
expect=''

# A pristine copy of everything verify.sh reads, and nothing else.
fixture() {
  local d
  d=$(mktemp -d) || return 1
  mkdir -p "$d/scripts"
  cp -R manifest.json _locales images store "$d/" || return 1
  cp -p scripts/verify.sh scripts/package.sh "$d/scripts/" || return 1
  printf '%s' "$d"
}

# Rewrite a JSON file through a python statement; `m` is the parsed document.
# argv rather than string interpolation, so a mutation can contain any quoting.
pyedit() {
  python3 -c 'import json, sys
p, stmt = sys.argv[1], sys.argv[2]
m = json.load(open(p, encoding="utf-8"))
exec(stmt)
json.dump(m, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)' "$1" "$2"
}

# Write store/icon-128.png in a chosen shape. One helper, so the PNG chunk
# scaffolding is defined once:
#   padded   a correct icon whose rows use every filter type; must be accepted
#   opaque   right geometry, no transparent border
#   deep16   16-bit samples
#   garbage  valid header, undecodable pixel data
write_store_icon() {
  python3 - "$1" <<'PY'
import struct, sys, zlib

mode, w, h, pad = sys.argv[1], 128, 128, 16
depth = 16 if mode == 'deep16' else 8

def chunk(tag, body):
    return struct.pack('>I', len(body)) + tag + body + struct.pack('>I', zlib.crc32(tag + body))

# Encode one row. The mirror of unfilter() in scripts/verify.sh, written
# independently so a shared bug cannot cancel itself out.
def filt(cur, prev, f, bpp=4):
    out = bytearray(len(cur))
    for i in range(len(cur)):
        a = cur[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        if f == 0:
            out[i] = cur[i]
        elif f == 1:
            out[i] = (cur[i] - a) & 0xff
        elif f == 2:
            out[i] = (cur[i] - b) & 0xff
        elif f == 3:
            out[i] = (cur[i] - ((a + b) >> 1)) & 0xff
        else:
            pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
            p = a if pa <= pb and pa <= pc else b if pb <= pc else c
            out[i] = (cur[i] - p) & 0xff
    return bytes(out)

if mode == 'deep16':
    raw = b''.join(b'\x00' + b'\x18\x18\x1b\x1b\x28\x28\xff\xff' * w for _ in range(h))
elif mode == 'opaque':
    raw = b''.join(b'\x00' + b'\x18\x1b\x28\xff' * w for _ in range(h))
else:
    # Transparent 16px border, opaque 96x96 centre: what the store requires.
    # Rows cycle through all five filter types, which is what any image editor
    # emits and what a filter-0 assumption used to reject.
    rows, prev = bytearray(), bytes(w * 4)
    for y in range(h):
        row = b''.join(b'\x7a\xa2\xf7\xff' if pad <= x < w - pad and pad <= y < h - pad
                       else b'\x00\x00\x00\x00' for x in range(w))
        f = y % 5
        rows += bytes([f]) + filt(row, prev, f)
        prev = row
    raw = bytes(rows)

open('store/icon-128.png', 'wb').write(
    b'\x89PNG\r\n\x1a\n'
    + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, depth, 6, 0, 0, 0))
    + chunk(b'IDAT', b'not zlib data' if mode == 'garbage' else zlib.compress(raw))
    + chunk(b'IEND', b''))
PY
}

# --- cases verify.sh must accept ---------------------------------------------

tweak_repository_is_unmodified() { :; }

tweak_store_icon_uses_every_png_filter() { write_store_icon padded; }

# --- cases verify.sh must reject ---------------------------------------------
# Every mutate_* function runs with the fixture as cwd and sets `expect` to a
# fragment of the message it should provoke. Without `expect` a case can pass
# for the wrong reason: a 48x48 RGB icon trips the size check and the colour
# type check, and only one of those is the branch under test.

mutate_default_locale_is_not_en() {
  expect="default_locale: expected 'en'"
  pyedit manifest.json 'm["default_locale"] = "pt"'
}

mutate_theme_key_is_absent() {
  expect='theme.colors is missing or empty'
  pyedit manifest.json 'del m["theme"]'
}

mutate_theme_colours_are_absent() {
  expect='theme.colors is missing or empty'
  pyedit manifest.json 'del m["theme"]["colors"]'
}

mutate_theme_colours_are_empty() {
  expect='theme.colors is missing or empty'
  pyedit manifest.json 'm["theme"]["colors"] = {}'
}

mutate_colour_component_exceeds_255() {
  expect='is not three integers 0-255'
  pyedit manifest.json 'm["theme"]["colors"]["toolbar"] = [999, 0, 0]'
}

mutate_colour_component_is_negative() {
  expect='is not three integers 0-255'
  pyedit manifest.json 'm["theme"]["colors"]["toolbar"] = [-1, 0, 0]'
}

mutate_colour_component_is_a_boolean() {
  expect='is not three integers 0-255'
  pyedit manifest.json 'm["theme"]["colors"]["toolbar"] = [True, 0, 0]'
}

mutate_colour_has_two_components() {
  expect='is not three integers 0-255'
  pyedit manifest.json 'm["theme"]["colors"]["toolbar"] = [36, 40]'
}

# The likeliest hand-edit of this file: pasting a hex string where Chrome
# wants a triple.
mutate_colour_is_a_hex_string() {
  expect='is not three integers 0-255'
  pyedit manifest.json 'm["theme"]["colors"]["toolbar"] = "#24283b"'
}

mutate_theme_image_is_absent() {
  expect='does not exist'
  rm images/ntp_background.png
}

mutate_theme_image_is_not_a_png() {
  expect='is not a PNG'
  mv images/ntp_background.png images/ntp_background.webp
  pyedit manifest.json 'm["theme"]["images"]["theme_ntp_background"] = "images/ntp_background.webp"'
}

mutate_version_line_loses_its_spacing() {
  expect='the version line no longer matches'
  sed -i 's/^  "version": /  "version":/' manifest.json
}

mutate_locale_file_is_absent() {
  expect='_locales/pt_BR/messages.json: missing'
  rm _locales/pt_BR/messages.json
}

mutate_locale_key_is_absent() {
  expect='_locales/en/messages.json: name missing'
  pyedit _locales/en/messages.json 'del m["name"]'
}

mutate_name_exceeds_75_chars() {
  expect='name is 76 chars, limit 75'
  pyedit _locales/en/messages.json 'm["name"]["message"] = "x" * 76'
}

mutate_description_exceeds_132_chars() {
  expect='description is 133 chars, limit 132'
  pyedit _locales/pt_BR/messages.json 'm["description"]["message"] = "x" * 133'
}

mutate_extension_icon_is_the_wrong_size() {
  expect='images/icon-48.png: 16x16, must be 48x48'
  cp images/icon-16.png images/icon-48.png
}

mutate_tile_is_absent() {
  expect='store/tile-440x280.png: missing'
  rm store/tile-440x280.png
}

mutate_tile_is_the_wrong_size() {
  expect='store/tile-440x280.png: 128x128, must be 440x280'
  cp images/icon-128.png store/tile-440x280.png
}

mutate_screenshots_are_absent() {
  expect='0 PNGs, the store takes one to five'
  rm -f store/screenshots/*.png
}

mutate_screenshot_is_the_wrong_size() {
  expect='store/screenshots/01-new-tab.png: 128x128, must be 1280x800'
  cp images/icon-128.png store/screenshots/01-new-tab.png
}

mutate_store_icon_is_absent() {
  expect='store/icon-128.png: missing'
  rm store/icon-128.png
}

mutate_store_icon_is_not_128_square() {
  expect='store/icon-128.png: 48x48, must be 128x128'
  cp images/icon-48.png store/icon-128.png
}

mutate_store_icon_has_no_alpha_channel() {
  expect='must be 6 (RGBA)'
  cp images/icon-128.png store/icon-128.png       # the shipped icon is RGB
}

mutate_store_icon_is_not_a_png() {
  expect='store/icon-128.png: not a PNG'
  printf 'this is not a png' > store/icon-128.png
}

# Distinct from the case above: the chunks are all intact, so only the signature
# check can catch this. Junk bytes are caught either way, by the absence of an
# IHDR, which leaves the signature check untested unless a file gets this far.
mutate_store_icon_signature_is_corrupt() {
  expect='store/icon-128.png: not a PNG'
  python3 - <<'PY'
d = bytearray(open('store/icon-128.png', 'rb').read())
d[1] = 0x00
open('store/icon-128.png', 'wb').write(bytes(d))
PY
}

mutate_store_icon_pixels_do_not_decode() {
  expect='the file is corrupt'
  write_store_icon garbage
}

mutate_store_icon_is_16_bit() {
  expect='bit depth 16, expected 8'
  write_store_icon deep16
}

# verify.sh reads the interlace flag rather than the Adam7 layout, so flipping
# the byte (and repairing IHDR's CRC) is enough to exercise the check.
mutate_store_icon_is_interlaced() {
  expect='interlaced'
  python3 - <<'PY'
import struct, zlib
d = bytearray(open('store/icon-128.png', 'rb').read())
d[28] = 1                                            # IHDR data, last byte
d[29:33] = struct.pack('>I', zlib.crc32(bytes(d[12:29])))
open('store/icon-128.png', 'wb').write(bytes(d))
PY
}

mutate_store_icon_border_is_opaque() {
  expect='is not transparent'
  write_store_icon opaque
}

mutate_package_script_is_not_executable() {
  expect='FAIL scripts/package.sh'
  chmod -x scripts/package.sh
}

# --- runner ------------------------------------------------------------------
report() {
  if [ "$2" = ok ]; then
    echo "  ok   $1"
    pass=$((pass + 1))
  else
    echo "  FAIL $1: $3"
    fail=$((fail + 1))
  fi
}

# run_case <function> reject|accept
run_case() {
  local fn=$1 mode=$2 name d out rc=0
  if [ "$mode" = reject ]; then
    name=should_fail_when_${fn#mutate_}
  else
    name=should_pass_when_${fn#tweak_}
  fi

  d=$(fixture) || { report "$name" bad 'could not build the fixture'; return; }
  expect=''
  cd "$d" && "$fn"
  cd "$ROOT" || exit 1
  out=$("$d/scripts/verify.sh" 2>&1) || rc=$?

  if [ "$mode" = accept ]; then
    if [ "$rc" -eq 0 ]; then
      report "$name" ok
    else
      report "$name" bad 'verify.sh rejected a tree it should accept'
      printf '%s\n' "$out" | sed 's/^/         /'
    fi
  elif [ -z "$expect" ]; then
    # grep -F with an empty pattern matches anything, which would turn this
    # into an exit-code-only assertion without saying so.
    report "$name" bad "$fn set no expected message"
  elif [ "$rc" -eq 0 ]; then
    report "$name" bad 'verify.sh still passed'
  elif ! grep -qF -- "$expect" <<<"$out"; then
    report "$name" bad "failed, but not on '$expect'"
    printf '%s\n' "$out" | sed 's/^/         /'
  else
    report "$name" ok
  fi

  [ -n "$d" ] && rm -rf "$d"
}

# Cases are discovered by introspecting the function table, so adding one needs
# no second registration. sort, so run order does not depend on bash's hash.
cases() { declare -F | awk '{print $3}' | grep "^$1" | sort; }

echo "verify.sh accepts what it should"
while read -r fn; do run_case "$fn" accept; done < <(cases tweak_)

echo "verify.sh rejects each broken invariant"
while read -r fn; do run_case "$fn" reject; done < <(cases mutate_)

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
