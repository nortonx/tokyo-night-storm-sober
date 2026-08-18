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

All text pairs pass WCAG AA; the weakest is the idle tab label at 4.74:1.

Tab identity used to rest entirely on label contrast. That works in the
horizontal strip and fails completely in Chrome's vertical tab strip collapsed
to favicons, which has no labels, so the surfaces have to carry the cue alone.

The active tab's fill cannot be themed. `kOverwritableColorTable` has no
`COLOR_TAB_BACKGROUND_ACTIVE_*` entry, so it falls back to `kColorToolbar`.
With `toolbar` held at Storm's `#24283b`, the only lever left is the idle tab,
and the useful direction is counter-intuitive: darkening it is capped at 1.44:1
even against pure black, while lightening it works, because contrast is
symmetric and the toolbar never has to move.

| pair | WCAG | APCA |
|---|---|---|
| active `#24283b` vs idle `#4a5273` | 1.90 | Lc 17.3 |
| idle vs strip background `#181b28` | 2.24 | Lc 19.4 |
| active vs strip background | 1.18 | Lc 5.8 |
| active label `#c0caf5` vs idle label on its own surface | 9.02 / 4.74 | Lc 77 / 64 |

`background_tab` `#4a5273` is the midpoint of Storm's `fg_gutter #414868` and
`dark3 #545c7e`. Going lighter is not free: nothing in Tokyo Night reaches AA on
`#545c7e`, where `#c0caf5` gives 4.05:1 and only pure white passes, so the label
would have to leave the palette.

Surface separation is still under WCAG 1.4.11's 3:1, which needs `#6874ab`,
outside the palette entirely. APCA measures dark-on-dark far better than WCAG 2.x
does, and Lc 17.3 clears its Lc 15 floor for non-text elements. The active tab
sits close to the strip background (Lc 5.8) and reads as a dark notch between
lighter chips rather than as a lit chip of its own.

The lighter idle tab also helps favicons, which the theme cannot recolour: a
near-black favicon goes from 1.12:1 to 2.28:1 against an idle tab. On the active
tab it stays at 1.19:1 and is effectively invisible. Holding `toolbar` at Storm's
value makes that unfixable, and it is a real cost of the decision.

`tab_background_text_inactive` is deliberately absent. With it unset, Chrome
derives the unfocused-window label from `tab_background_text` and guarantees
4.5:1 against whatever surface ships, instead of a hand-picked value that has to
be re-tuned whenever a background moves.

## Platform constraints

Established from source, not assumed. Each one shaped a decision here.

| constraint | source |
|---|---|
| Theme images must be PNG. No WebP or JPEG. | [themes docs](https://developer.chrome.com/docs/extensions/develop/ui/themes) |
| Valid colour keys are fixed by `kOverwritableColorTable`. There is no domain-specific omnibox key and no per-icon key. | [browser_theme_pack.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/themes/browser_theme_pack.cc) |
| `omnibox_text` applies to the URL host only; scheme and path use a separately derived colour that themes cannot set. | [omnibox_color_mixer.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/ui/color/omnibox_color_mixer.cc) |
| `default_locale` is required whenever `_locales/` exists. | [default_locale](https://developer.chrome.com/docs/extensions/reference/manifest/default-locale) |
| `name` max 75 chars; `description` max 132, plain text. | [description](https://developer.chrome.com/docs/extensions/reference/manifest/description) |
| Screenshots exactly 1280x800 or 640x400, square corners, no padding. Store icon is 96x96 artwork in 128x128 with transparent padding. | [images](https://developer.chrome.com/docs/webstore/images) |
| The API can update a store item but cannot create one. | [CWS API](https://developer.chrome.com/docs/webstore/using-api) |
| Incognito windows ignore custom themes entirely. `BrowserThemeProvider::GetThemeSupplier()` returns `nullptr` whenever `incognito_` is set, and incognito profiles are handed exactly that provider. The `*_incognito` keys are valid but inert, so this theme does not ship them. | [theme_service.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/themes/theme_service.cc) |
| The active tab's fill is `kColorToolbar`. There is no themeable active-tab background, and no key for tab strokes, dividers, outlines or the vertical strip. Dividers are `kColorToolbar` too. | [tab_strip_color_mixer.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/ui/color/tab_strip_color_mixer.cc) |
| Omit a tab foreground and Chrome generates it to a target ratio (10.46 active, 7.98 idle, 4.5 unfocused) instead of using a theme value. | same |
| The new tab button's background follows `background_tab`, so it moves with the idle tabs. | same |
| An unrecognised colour key is ignored in silence, not rejected. `verify.sh` checks key names for this reason. | [browser_theme_pack.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/themes/browser_theme_pack.cc) |

## Development

```bash
./tests/verify_test.sh   # prove verify.sh's own checks still fire
./scripts/verify.sh      # the store limits CI also checks
./scripts/package.sh     # build the store ZIP into dist/
```

`verify.sh` is the only thing standing between a bad edit and a store
rejection, and a check that silently stops checking looks exactly like a
passing one. `tests/verify_test.sh` breaks one invariant at a time in a
throwaway copy of the tree and asserts `verify.sh` notices, so CI runs it
first.

Load unpacked from the repository root via `chrome://extensions`. Chrome writes
a `Cached Theme.pak` there when it does; it is git-ignored and safe to delete.

The package is built from an allowlist of `manifest.json`, `images/`, and
`_locales/`. That guards the repository root; anything placed *inside* those
directories does ship, so keep them clean.

## Releasing

Merging to `main` releases whatever the conventional commits imply. Run the
`release` workflow by hand to force a level: `auto` cannot produce a major
below 1.0.0, because semver makes a breaking change in 0.x a minor.

Tagging `v<version>` builds and publishes the package. The API moves the
package only. These are Dashboard-only and must be done by hand:

- [ ] Detailed description, English
- [ ] Detailed description, Portuguese, via the locale dropdown
- [ ] Screenshots, exactly 1280x800, one to five, from `store/screenshots/`
- [ ] Store icon `store/icon-128.png` and the tile `store/tile-440x280.png`
- [ ] Category and language
- [ ] Privacy tab: no permissions, no data collected

### Store setup, once

`publish.yml` skips its store half until all five of these are set, so a release
packages and stays green rather than failing red on a missing credential.

| name | kind | where it comes from |
|---|---|---|
| `GCP_PROJECT_ID` | variable | the Google Cloud project holding the service account |
| `GCP_WIF_PROVIDER` | secret | `projects/<number>/locations/global/workloadIdentityPools/github/providers/github` |
| `GCP_SERVICE_ACCOUNT` | secret | `cws-publisher@<project>.iam.gserviceaccount.com` |
| `CWS_PUBLISHER_ID` | secret | Dashboard, Publisher then Settings |
| `CWS_EXTENSION_ID` | secret | the item's 32-character ID, from the Dashboard URL |

The service account needs no IAM role. It needs `roles/iam.workloadIdentityUser`
granted *to* it for the pool attribute `repository == nortonx/tokyo-night-storm-sober`,
and its email added under Account in the Chrome Web Store Dashboard. Only one
service account per publisher is accepted. The provider must carry an attribute
condition pinning the repository, or any GitHub repository can assume it.

There is no JSON key anywhere, by design. Federation mints a short-lived token
per run.

To exercise the credentials without submitting anything for review, run the
`publish` workflow by hand with `publish = false`: it uploads a draft package
and stops.

### Screenshots

DevTools and Playwright capture page content, not browser chrome, so these must
be taken with an OS screenshot tool. `--load-extension` does not apply a theme
either; install it via `chrome://extensions` first.

Capture the window at any size, then normalise each one into
`store/screenshots/`:

    magick shot.png -bordercolor none -trim +repage \
      -background '#181b28' -alpha remove \
      -resize 1280x800^ -gravity center -extent 1280x800 \
      -type TrueColor -strip store/screenshots/01-newtab.png

The trim removes the compositor's rounded corners and drop shadow, which the
store counts as padding. Capturing larger than 1280x800 is preferred:
downscaling supersamples, so text stays crisp.

The store takes JPEG or 24-bit PNG with no alpha, and `verify.sh` accepts
either: one to five files in `store/screenshots/`, each exactly 1280x800, and
it rejects a PNG carrying an alpha channel. What ships here is JPEG at quality
92 with no chroma subsampling, since 4:2:0 smears the text in a screenshot:

    magick shot.png -quality 92 -sampling-factor 4:4:4 -strip shot.jpg

Suggested set: new tab, two or three tabs with a URL showing the green domain,
the vertical tab strip collapsed so the active tab's darker chip is visible. Not
an incognito window: it renders with no theme at all.

### Two different 128x128 icons

`images/icon-128.png` is the extension icon. It is full bleed and ships in the
package. `store/icon-128.png` is the store listing icon: the same artwork at
96x96 centred in 128x128 with transparent padding, which the store requires. It
never ships. Both are committed PNGs; edit them with an image editor.

`verify.sh` checks that the store icon's 16px border is actually transparent,
and decodes all five PNG row filters to do it, so any normal export works. It
also checks that every icon and the tile match their declared dimensions.
