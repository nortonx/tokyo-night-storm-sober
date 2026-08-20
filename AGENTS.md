# AGENTS.md — Tokyo Night Storm (Reading)

Instructions for AI agents working in this repo. Canonical file: `CLAUDE.md` and
`.github/copilot-instructions.md` point here.

## Stack

No runtime, no package manager, no dependencies. The deliverable is a Chrome MV3
theme (`manifest.json` plus PNGs and `_locales/`); the tooling around it is bash
and Python 3 stdlib.

| Path | What it is |
| ---- | ---------- |
| `manifest.json` | The theme itself: MV3 manifest, the colour table, NTP properties. Carries the version. |
| `images/` | Extension icons (16/32/48/128) and the new-tab background. Ships in the package. |
| `_locales/en`, `_locales/pt_BR` | `name` and `description`, referenced from the manifest as `__MSG_*__`. Ships. |
| `store/` | Listing assets: padded store icon, promo tile, screenshots, listing copy. Never ships. |
| `scripts/verify.sh` | The store-limit checks. Every CI leg runs it. |
| `scripts/package.sh` | Builds `dist/*.zip` from an allowlist. |
| `tests/verify_test.sh` | Mutation tests over `verify.sh`. |
| `.github/workflows/` | `ci` (pull requests), `release` (bump and tag), `publish` (Web Store). |
| `cog.toml` | cocogitto: bump rules, changelog, the manifest version-sync hook. |

## Commands

```bash
./tests/verify_test.sh        # mutation tests over verify.sh; CI runs this FIRST
./scripts/verify.sh           # store limits: manifest shape, locale lengths, image geometry
./scripts/package.sh          # build dist/tokyo-night-storm-reading-<version>.zip
cog check --from-latest-tag   # lint the commit range, as CI does
cog install-hook --all        # once per clone; the config alone writes no hook
```

There is no install, lint, format, typecheck, or build step beyond these. Do not
add one to satisfy a habit. Requires `python3`, `zip`, `bash`, and cog 7.x.

Load unpacked from the repository root via `chrome://extensions`.

## Non-obvious constraints

1. **The version line's shape is load-bearing.** It lives in `manifest.json` and
   cog rewrites it with a sed pinned to exactly `  "version": "x.y.z",`
   (`cog.toml:23`). Reformat that line and the bump silently no-ops, tagging a
   release whose manifest still says the old version. `scripts/verify.sh:66`
   guards the shape.
2. **A new check in `verify.sh` needs a matching case in `tests/verify_test.sh`.**
   The suite runs *before* `verify.sh` in all three workflows on purpose: a check
   that has silently stopped checking passes exactly like a healthy one. Cases are
   discovered by function prefix, so no registration is needed — `mutate_*` must
   make `verify.sh` fail, `tweak_*` must leave it passing — but a `mutate_` case
   that sets no `expect=` is reported as a failure, not a pass.
3. **The package is an allowlist, not an exclude list**
   (`scripts/package.sh:11`: `manifest.json images _locales LICENSE`). A new file
   at the root does not ship. A new file *inside* `images/` or `_locales/` does.
4. **`.claude/`, `.agent/`, and `openspec/` are gitignored.** Local agent tooling,
   absent from a fresh clone. `AGENTS.md`, `CLAUDE.md`, and
   `.github/copilot-instructions.md` are tracked.
5. **`verify.sh` asserts colour *shape*, never colour values**, and that now
   includes key *names*: a colour key outside `kOverwritableColorTable` is
   rejected, because Chrome ignores an unknown key in silence. Editing the
   palette is the work, not a defect to guard against. Do not add a second copy
   of the palette to assert the first one against.
6. **Two different 128x128 icons exist**, for different consumers, and only one
   of them ships. See README, "Two different 128x128 icons".
7. **Release chain.** Merging to `main` runs `release.yml`, which bumps, tags,
   and then *explicitly dispatches* `publish.yml` — a tag pushed with the ambient
   `GITHUB_TOKEN` does not fire a `push: tags` trigger. `cog bump` requires the
   `--skip-ci` flag; the `skip_ci` key in `cog.toml` only defines the marker
   string. `branch_whitelist = ["main"]`. See README, "Releasing".
8. **Conventional commits are linted over the commit range**
   (`cog check --from-latest-tag`), not from the PR title. `chore`, `ci`, `build`,
   `style`, `test`, and `docs` are omitted from the changelog and do not bump.
9. **The store listing is Dashboard-only.** Detailed descriptions, screenshots,
   category, and the privacy tab cannot be set through the API, which updates an
   existing item but cannot create one. `publish.yml` skips its store half until
   all five credentials are set, so a release stays green rather than failing red
   on a missing secret. See README, "Store setup, once".
10. **Store-facing copy is bilingual**, en and pt_BR (`_locales/`,
    `store/listing/README.md`). Code comments and commit messages stay English.

## Known gotchas

- `--load-extension` does not apply a theme, and DevTools or Playwright capture
  page content rather than browser chrome. Screenshots need an unpacked install
  via `chrome://extensions` plus an OS screenshot tool. See README, "Screenshots".
- `omnibox_text` colours the URL host only. A typed search query has no host, so
  it renders entirely in the accent colour. No theme key separates the two.
- Tab identity is carried by the tab **surfaces**, not the label: `background_tab`
  is deliberately lighter than `toolbar`, because the active tab's fill is not
  themeable and falls back to `kColorToolbar`. Chrome's collapsed vertical tab
  strip has no labels, which is what forced this. Separation is 1.90:1, still
  under WCAG 1.4.11's 3:1, which no Tokyo Night colour reaches. See README,
  "Contrast" before changing any tab colour.
- The `*_incognito` colour keys are absent on purpose. Incognito windows ignore
  custom themes outright: `BrowserThemeProvider::GetThemeSupplier()` returns
  `nullptr` whenever `incognito_` is set. The keys are valid but inert, so do not
  "restore" them. See README, "Platform constraints".
- Chrome writes `Cached Theme.pak` to the repository root when it loads the theme
  unpacked. Gitignored, safe to delete.
