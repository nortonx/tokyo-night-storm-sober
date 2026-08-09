#!/usr/bin/env python3
"""Set manifest.json's version field. Invoked by cog's pre_bump_hooks.

Rewrites only the one line rather than reserialising the document, because
manifest.json is hand-formatted with grouping blank lines that json.dump would
flatten, producing a large diff on every release.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, 'manifest.json')

VERSION_RE = re.compile(r'^\d+(\.\d+){0,3}$')


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: set_version.py <version>')
    version = sys.argv[1].lstrip('v')
    if not VERSION_RE.match(version):
        sys.exit(f'refusing version {version!r}: expected 1 to 4 dot-separated integers')

    with open(MANIFEST, encoding='utf-8') as fh:
        text = fh.read()

    new, count = re.subn(r'("version"\s*:\s*)"[^"]*"',
                         lambda m: f'{m.group(1)}"{version}"', text, count=1)
    if count != 1:
        sys.exit(f'expected exactly one "version" key in manifest.json, replaced {count}')

    with open(MANIFEST, 'w', encoding='utf-8') as fh:
        fh.write(new)

    # Fail loudly rather than emit a manifest Chrome would reject.
    got = json.loads(new)['version']
    if got != version:
        sys.exit(f'post-write check failed: manifest says {got!r}, expected {version!r}')
    print(f'manifest.json version -> {version}')


if __name__ == '__main__':
    main()
