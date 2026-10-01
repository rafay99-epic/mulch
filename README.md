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

Rules are data in `Sources/MulchCore/Catalog/BuiltInRules.swift`. Each one is **Auto** (cleaned by the weekly sweep), **Ask** (held in the inbox) or **Off**. Settings live in `~/.config/mulch/config.json` (Mulch Dev uses `~/.config/mulch-dev`), so they can be shared between Macs through dotfiles.

## Install on a Mac

```sh
brew install --cask rafay99-epic/apps/mulch
```

Mulch updates itself: shortly after launch and every six hours it checks the latest GitHub release and installs a newer build once nothing is being cleaned. Settings > General shows the version and has a manual check.

## Stable and Dev

| Build  | App           | Bundle ID               | Config                | Updates        |
| ------ | ------------- | ----------------------- | --------------------- | -------------- |
| Stable | Mulch.app     | `com.rafay99.mulch`     | `~/.config/mulch`     | latest release |
| Dev    | Mulch Dev.app | `com.rafay99.mulch.dev` | `~/.config/mulch-dev` | never          |

Each has its own config, history, log, menu bar icon and icon color, so both run side by side. Test a branch with `pnpm desktop:dev`: it builds Mulch Dev from your checkout and installs it to `/Applications` without touching Mulch.

## Releases

Every push to `main` that touches `apps/desktop` runs `.github/workflows/release.yml`: tests, build, sign, zip, and a GitHub Release `v<commit count>` titled `Mulch <commit count>` with `Mulch.zip`. Installed apps read the version from that title and download that zip, and the Homebrew cask installs `releases/latest/download/Mulch.zip`, so keep both names. Pull requests run `ci.yml` (Swift tests and the website build).

Releases are signed with the self-signed **Mulch Signing** identity from Actions secrets. To create or rotate it:

```sh
apps/desktop/Scripts/make-signing-cert.sh --github
```

Local builds sign with `CODESIGN_IDENTITY`, else your Apple Development certificate, else Mulch Signing, else ad-hoc.

## Logs and crashes

Each build writes `~/Library/Logs/<app name>/activity.log` (Settings > General > Activity log): launches with version and commit, scans, cleans, skips, failures and updates, as `<time>  INFO|ERROR|CRASH  <message>`. After a crash, the next launch adds a CRASH line pointing at the report macOS wrote in `~/Library/Logs/DiagnosticReports`. To follow a running app:

```sh
log stream --level info --predicate 'subsystem BEGINSWITH "com.rafay99.mulch"'
```

## Develop

```sh
pnpm install
pnpm desktop:test      # swift test
pnpm desktop:build     # build/Mulch.app (MULCH_CHANNEL=dev for Mulch Dev)
pnpm desktop:dev       # build and install Mulch Dev
pnpm web:dev           # website on localhost
pnpm web:build
```
