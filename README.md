# Tokyo Night Storm (Reading)

A Chrome theme. Tokyo Night Storm with contrast tuned for long reading sessions.

## Attribution

Tokyo Night is the work of [Enkia](https://github.com/tokyo-night/tokyo-night-vscode-theme),
distributed under the MIT License. This theme is a derived work: the palette
follows the canonical Storm variant, and the colour values here are Enkia's.
Those values were cross-checked against the
[tokyonight.nvim](https://github.com/folke/tokyonight.nvim) port by folke.

`LICENSE` carries this project's MIT terms and reproduces Enkia's upstream
notice. It ships inside the package as well as living in the repository, since
MIT requires the notice to travel with every copy and the package is what users
actually receive.

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
./scripts/verify.sh            # all invariants; CI runs exactly this
python3 scripts/gen_assets.py  # regenerate icons and tile from manifest colours
./scripts/package.sh           # build dist/tokyo-night-storm-reading-<version>.zip
```

Load unpacked from the repository root via `chrome://extensions`. Chrome writes
a `Cached Theme.pak` there when it does; it is git-ignored and safe to delete.

`scripts/gen_assets.py` uses only the Python standard library and is
byte-deterministic. CI regenerates the assets and fails if they differ from
what is committed, so an image library must never be introduced here.

The package is built from an allowlist of `manifest.json`, `images/`, and
`_locales/`. That guards the repository root; anything placed *inside* those
directories does ship, so keep them clean.

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
