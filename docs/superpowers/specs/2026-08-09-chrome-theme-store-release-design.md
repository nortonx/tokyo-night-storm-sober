# Tokyo Night Storm (Reading): Chrome Web Store release design

Date: 2026-08-09
Status: approved, not implemented

Scope: prepare the existing Chrome theme for publication on the Chrome Web Store. Covers palette
correction, internationalisation, asset optimisation, packaging, and a tag-triggered publish
pipeline.

## Starting state

The working tree contained three files, none of them committed:

| file | note |
|---|---|
| `manifest.json` | MV3 theme, 24 colour keys, one NTP image |
| `images/ntp_background.png` | 2560x1440, 672827 bytes |
| `Cached Theme.pak` | 1.8 MB, git-staged, Chrome-generated install cache |

The remote already existed and held one commit, `a416be7`, containing an MIT `LICENSE` for the
project. Work branches from that commit.

| | |
|---|---|
| repository | `nortonx/tokyo-night-storm-sober` |
| visibility | public |
| default branch | `main` |
| created | 2026-08-08 |

Absent: `.gitignore`, `_locales/`, icons, CI.

## Verified platform constraints

Established from source and official documentation, not assumed:

| constraint | source |
|---|---|
| Theme images must be PNG. No WebP or JPEG. | [themes docs](https://developer.chrome.com/docs/extensions/develop/ui/themes) |
| Valid colour keys are fixed by `kOverwritableColorTable`. There is no domain-specific omnibox key and no per-icon key. | [browser_theme_pack.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/themes/browser_theme_pack.cc) |
| `omnibox_text` overrides `kColorOmniboxText`, applied to the URL host only. Scheme and path use `kColorOmniboxTextDimmed`, derived separately and not themeable. | [omnibox_color_mixer.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/ui/color/omnibox_color_mixer.cc), confirmed empirically against a live browser |
| `default_locale` is required when `_locales/` exists. | [default_locale](https://developer.chrome.com/docs/extensions/reference/manifest/default-locale) |
| `name` max 75 chars; `description` max 132 chars, plain text. | [description](https://developer.chrome.com/docs/extensions/reference/manifest/description) |
| CWS API v2 supports service accounts. Items cannot be created by API. | [CWS API v2](https://developer.chrome.com/blog/cws-api-v2), [service accounts](https://developer.chrome.com/docs/webstore/service-accounts) |
| OAuth consent screens in Testing status issue refresh tokens that expire after 7 days regardless of configured lifetime. | [OAuth 2.0](https://developers.google.com/identity/protocols/oauth2) |

## 1. Repository layout and packaging

```
manifest.json                 ships
_locales/en/messages.json     ships
_locales/pt_BR/messages.json  ships
images/ntp_background.png     ships
images/icon-{16,32,48,128}.png ships, generated
store/tile-440x280.png        does not ship, generated
store/screenshots/            does not ship, manual
scripts/gen_assets.py
scripts/package.sh
.github/workflows/release.yml
.gitignore
README.md
LICENSE
```

Packaging uses an explicit allowlist (`manifest.json`, `images/`, `_locales/`), never an exclude
list, so a new stray file cannot leak into the package. `package.sh` fails if the manifest version
does not match the git tag, and prints the file list before zipping.

Hygiene, before the first commit:

- `git rm --cached "Cached Theme.pak"` and delete it from disk. Nothing in this repo regenerates it.
- `.gitignore`: `Cached Theme.pak`, `dist/`, `*.zip`
- The `.pak` was never committed, so removing it from the index before the first local commit keeps it out of history entirely.

Manifest additions: `default_locale: "en"`, `icons` at 16/32/48/128, and `name` / `description`
replaced with `__MSG_name__` / `__MSG_description__`.

## 2. Palette

### Measurement

All nine text pairs in the original manifest already pass WCAG AA, the weakest at 4.78:1 and most
above 6.5:1. No contrast repair was required.

The defect was variant mixing. Storm surfaces cluster at H229 +/- 1, S23-26%. Two imported Tokyo
Night **Night** values sat outside that cluster:

| keys | old | H | S | new | H | S |
|---|---|---|---|---|---|---|
| `frame`, `omnibox_background`, `ntp_background` | `#1a1b26` | 235 | 18.8% | `#181b28` | 229 | 24.0% |
| `frame_inactive`, `frame_incognito`, `frame_incognito_inactive`, `background_tab_inactive`, `background_tab_incognito_inactive` | `#16161e` | 240 | 15.4% | `#141620` | 229 | 24.0% |

Lightness is held constant (12.5% and 10.2%), so every contrast ratio moves by at most 0.02. The
other 14 keys were already canonical Storm and are unchanged.

### Accents

| key | value | effect |
|---|---|---|
| `omnibox_text` | `#73daca` (Storm `green1`) | URL host and the bookmark star inside the omnibox |
| `toolbar_button_icon` | `#f7768e` (Storm `red`) | toolbar buttons outside the omnibox |

`green1` was chosen over the three other canonical greens on three grounds: hue separation from
`#f7768e` is 178 degrees, near-complementary, against 100 degrees for `#9ece6a`; contrast of
10.28:1 is closest to the 10.61 baseline it replaces, so apparent brightness does not shift; and it
matches the reference theme the user identified.

Measured candidates on `#181b28`: `#9ece6a` 9.37, `#73daca` 10.28, `#1abc9c` 7.11, `#41a6b5` 5.99.
All pass AA.

### Deliberate non-change

Surface-to-surface separation stays below WCAG 1.4.11. `toolbar` against `background_tab` is
1.07:1. Reaching 3:1 from `#24283b` requires lightness 52% (`#6772a2`), a mid-grey tab strip that
is not Tokyo Night. Tab identity is carried by label contrast instead: active `#c0caf5` at 9.02:1
against idle `#9aa5ce` at 6.41:1. This is recorded in the README as a considered decision rather
than left as a silent audit failure.

### Accepted consequence

A typed search query in the omnibox has no host to isolate, so the whole string renders in the
accent colour. No key separates URL text from query text. Accepted by the user.

## 3. Internationalisation and store copy

`default_locale: "en"`, with `_locales/en/` and `_locales/pt_BR/`. Chrome resolves the user locale
and falls back to `en`.

| field | chars | value |
|---|---|---|
| `name` | 27/75 | Tokyo Night Storm (Reading) |
| `description` en | 123/132 | Tokyo Night Storm with contrast tuned for long reading sessions. Enkia's canonical palette. Mint address bar, red controls. |
| `description` pt_BR | 123/132 | Tokyo Night Storm com contraste ajustado para longas sessões de leitura. Paleta canônica da Enkia. Endereço em verde menta. |

Accents are restored. Both files are UTF-8.

The name avoids collision with the published "Tokyo Night Storm Theme" and leads with the benefit
rather than the internal "sober" label.

`_locales` covers the name and the 132-character summary only. The long store description,
screenshots, and category are entered per locale in the Developer Dashboard and never ship in the
package. This is a manual release-checklist item, not a pipeline step.

Attribution: the project's own MIT `LICENSE` (Copyright 2026 Norton Almeida) already exists at
`a416be7` and needs no change. What is still missing is upstream credit: Tokyo Night is Enkia's,
also MIT. Credit appears in both store descriptions, and the README carries an attribution section
reproducing Enkia's copyright notice, as MIT requires for a derived work.

## 4. Assets

### NTP background

Analysis of the source: 238 unique colours, dither noise present (five distinct values in one 6x6
block), a faint horizontal component of at most 6/255, and banding baked into the vertical ramp
that the dither does not successfully mask.

| approach | size | max delta | mean delta |
|---|---|---|---|
| original | 658 KB | - | - |
| lossless recompress | 440 KB | 0 | 0 |
| **per-row mean** | **5.8 KB** | 5/255 | **0.50/255** |
| regenerated smooth ramp | 27 KB | 9/255 | 2.29/255 |

Chosen: per-row mean. Method is `-resize 1x1440! -resize 2560x1440!`, collapsing each row to its
mean and restoring width. The vertical profile is retained at full 1440-row resolution, each row
taking that row's mean colour; the sub-perceptual horizontal variation and the dither noise are
discarded, which is why the maximum delta is 5/255 rather than 0. PNG row filters then compress the
resulting constant rows to almost nothing. Verified visually at normal contrast as
indistinguishable from the original.

The original's banding is inherent to its 8-bit quantisation and is preserved by this method. A
smooth ramp fitted to the row-mean profile would remove it at roughly 25 KB; not selected.

### Generated icons and tile

`scripts/gen_assets.py` reads colours from `manifest.json` and emits `images/icon-{16,32,48,128}.png`
and `store/tile-440x280.png`. Deterministic and committed, so the icon cannot drift from the palette.

Mark: an abstraction of the theme's own three-step surface ladder (frame, inactive tab, toolbar) as
stacked bars with a mint rule for the omnibox.

### Screenshots

Manual, 1280x800 PNG, 1 to 5 images. Cannot be automated: DevTools and Playwright capture page
content, not browser chrome. Suggested set: the NTP, tabs with the omnibox showing a green domain,
and an incognito window.

## 5. Release automation

### Authentication

Service account, not OAuth user credentials. The service account is created in Google Cloud with
no IAM roles, then authorised by adding its email under Account in the Developer Dashboard. One
service account per publisher.

This removes the 7-day refresh-token expiry entirely: there is no refresh token and no consent
screen. Each run mints a short-lived access token. Workload Identity Federation is preferred over
a JSON key so that no long-lived credential is stored.

### Prerequisites, manual and one-time

1. Developer registration and 2-step verification. Done.
2. Create the item in the Dashboard by uploading a package by hand. The API cannot create items.
   This yields the extension ID.
3. Complete the Store listing and Privacy tabs.
4. Read the publisher ID from Publisher > Settings.
5. Create the service account and authorise it.

Step 2 and onward are blocked until implementation produces `scripts/package.sh`, `_locales/`, and
the generated assets. Step 4 and the whole service-account setup are unblocked immediately.

### Workflow, triggered on `v*` tags

| step | action | verification |
|---|---|---|
| 1 | guard | manifest version equals tag, else fail |
| 2 | regenerate assets | non-empty `git diff` fails the run |
| 3 | package | allowlist only; assert exactly three entries |
| 4 | authenticate | mint short-lived token |
| 5 | upload | `POST /upload/v2/publishers/{pid}/items/{id}:upload` |
| 6 | publish | `POST /v2/publishers/{pid}/items/{id}:publish` |
| 7 | release | attach ZIP to the GitHub Release |

A `workflow_dispatch` entry point runs steps 1 to 5 and stops before publishing, to prove
credentials and packaging without shipping.

CI holds four values: `CWS_EXTENSION_ID`, `CWS_PUBLISHER_ID`, the service account email, and the
WIF provider resource name. With federation none is a leakable secret.

Repository visibility is public, with two consequences. Actions minutes are free, so the pipeline
costs nothing to run. And because the workflow triggers only on `v*` tags pushed by the owner, it
is never invoked by a pull request from a fork, which is the usual route by which a public
repository leaks secrets to untrusted code. Do not add a `pull_request` trigger to this workflow.

The federation pool must pin the repository claim. A provider created without an attribute
condition will mint tokens for any GitHub repository on the platform, not only this one, which
would let an unrelated repository authenticate as this publisher's service account. The condition
must assert the exact repository:

```
assertion.repository == 'nortonx/tokyo-night-storm-sober'
```

This matters more than repository visibility. A private repository with an unpinned provider is
worse than a public repository with a pinned one.

### Out of scope for the pipeline

Listing copy, screenshots, category, and pt-BR listing text are Dashboard-only. The pipeline moves
the package and nothing else.

## Open items

- Whether the green reads correctly on typed search queries. Resolvable only after install.
- Which toolbar icons follow `toolbar_button_icon` in practice. Expected: everything outside the
  omnibox. Confirm after install.
- Whether `store/screenshots/` should be committed or ignored. Currently specified as committed so
  listing assets are versioned with the theme they depict.

## Assessment

For a theme that changes a few times a year, the publish pipeline is more machinery than the task
requires; manual upload is a two-minute operation. It is included because it was explicitly
requested. Dropping to a build-and-attach workflow would remove the service account, the four CI
values, and the entire authentication surface at little cost.
