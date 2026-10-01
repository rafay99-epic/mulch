# Mulch

A menu bar app that clears dev junk off your Mac every week: build output, browser update leftovers, editor snapshots, package caches. It asks before anything risky and never touches worktrees, emulators or simulators.

## Layout

```
apps/
  desktop/   SwiftUI menu bar app (macOS 26+, built with Xcode 27)
  website/   Vite + React + Tailwind + Motion + shadcn/ui
```

### Desktop

Three SwiftPM targets, dependencies point one way:

| Target      | Owns                                                        | Imports            |
| ----------- | ----------------------------------------------------------- | ------------------ |
| `MulchCore` | rules, scanner, cleaner, config, history                    | Foundation         |
| `MulchUI`   | presentational SwiftUI components and screens               | SwiftUI, Charts    |
| `Mulch`     | the app: store, core-to-UI mapping, scenes, system services | MulchCore, MulchUI |

`MulchUI` never imports `MulchCore`. `Mulch/State/Presenter.swift` is the only place that knows both sides.

Rules are data in `Sources/MulchCore/Catalog/BuiltInRules.swift`. Each one is **Auto** (cleaned by the weekly sweep), **Ask** (held in the inbox) or **Off**. Settings live in `~/.config/mulch/config.json`, so they can be shared between Macs through dotfiles.

## Install on a Mac

Latest release (needs `gh` signed in with access to this repo):

```sh
gh repo clone rafay99-epic/mulch ~/Code/mulch
~/Code/mulch/apps/desktop/Scripts/install-release.sh
```

Or build from source: `apps/desktop/Scripts/install.sh`.

## Releases

Every push to `main` that touches `apps/desktop` runs `.github/workflows/release.yml`: tests, build, sign, zip, and a GitHub Release tagged `v<commit count>`. The version number is the commit count, so build 42 is `v42`. Pull requests run `ci.yml` (Swift tests and the website build).

Releases are signed with the self-signed **Mulch Signing** identity from Actions secrets. To create or rotate it:

```sh
apps/desktop/Scripts/make-signing-cert.sh --github
```

Local builds sign with `CODESIGN_IDENTITY`, else your Apple Development certificate, else Mulch Signing, else ad-hoc.

## Develop

```sh
pnpm install
pnpm desktop:test      # swift test
pnpm desktop:build     # build/Mulch.app
pnpm web:dev           # website on localhost
pnpm web:build
```
