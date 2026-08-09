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
    'tab_background_text': [154, 165, 206],
    'tab_background_text_inactive': [121, 130, 169],
    'tab_background_text_incognito': [154, 165, 206],
    'tab_background_text_inactive_incognito': [121, 130, 169],
}
bad = []
for k, v in {**expected, **unchanged}.items():
    if c.get(k) != v:
        bad.append(f"{k}: expected {v}, got {c.get(k)}")
# Every key is named above, so the total pins that none was added or dropped.
if len(c) != len(expected) + len(unchanged):
    bad.append(f"key count: expected {len(expected) + len(unchanged)}, got {len(c)}")
if bad:
    print("\n".join("    " + b for b in bad)); sys.exit(1)
PY
check "all 24 colour keys present: 10 corrected, 14 untouched" "$rc"

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

exit $fail
