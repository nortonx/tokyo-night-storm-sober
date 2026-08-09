# Tokyo Night Storm (Reading)

A Chrome theme. Tokyo Night Storm with contrast tuned for long reading sessions.

## Attribution

Tokyo Night is the work of [Enkia](https://github.com/tokyo-night/tokyo-night-vscode-theme),
distributed under the MIT License. This theme is a derived work: the palette
follows the canonical Storm variant, and the colour values here are Enkia's.

The canonical source is `themes/tokyo-night-storm-color-theme.json` in that
repository. Every colour used here was verified present in that file. The older
`enkia/tokyo-night-vscode-theme` URL returns HTTP 301 to the `tokyo-night` org;
cite the current one. [tokyonight.nvim](https://github.com/folke/tokyonight.nvim)
is a port, not the source, and should not be cited as the origin.

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
./scripts/verify.sh   # store limits CI also checks
./scripts/package.sh  # build dist/tokyo-night-storm-reading-<version>.zip
```

Load unpacked from the repository root via `chrome://extensions`. Chrome writes
a `Cached Theme.pak` there when it does; it is git-ignored and safe to delete.

The package is built from an allowlist of `manifest.json`, `images/`, and
`_locales/`. That guards the repository root; anything placed *inside* those
directories does ship, so keep them clean.

## Releasing

Tagging `v<version>` builds and publishes the package. The API moves the
package only. These are Dashboard-only and must be done by hand:

- [ ] Detailed description, English
- [ ] Detailed description, Portuguese, via the locale dropdown
- [ ] Screenshots, exactly 1280x800, one to five, from `store/screenshots/`
- [ ] Store icon `store/icon-128.png` and the tile `store/tile-440x280.png`
- [ ] Category and language
- [ ] Privacy tab: no permissions, no data collected

### Screenshots

DevTools and Playwright capture page content, not browser chrome, so these must
be taken with an OS screenshot tool. `--load-extension` does not apply a theme
either; install it via `chrome://extensions` first.

Capture the window at any size, then normalise:

    scripts/prepare_screenshots.sh ~/Pictures/shot-*.png

That trims the compositor's rounded corners and drop shadow, which the store
counts as padding, removes the alpha channel, and fits the result to exactly
1280x800. Capturing larger than 1280x800 is preferred: downscaling supersamples,
so text stays crisp. Output lands in `store/screenshots/`.

Suggested set: new tab, two or three tabs with a URL showing the green domain,
an incognito window.

### Two different 128x128 icons

`images/icon-128.png` is the extension icon. It is full bleed and ships in the
package. `store/icon-128.png` is the store listing icon: the same artwork at
96x96 centred in 128x128 with transparent padding, which the store requires. It
never ships. Both are committed PNGs; edit them with an image editor.
