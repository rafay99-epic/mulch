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

```sh
gh repo clone rafay99-epic/mulch ~/Code/mulch
cd ~/Code/mulch/apps/desktop
./Scripts/make-signing-cert.sh   # once per Mac, keeps permissions across rebuilds
./Scripts/install.sh             # again after every git pull
```

## Develop

```sh
pnpm install
pnpm desktop:test      # swift test
pnpm desktop:build     # build/Mulch.app
pnpm web:dev           # website on localhost
pnpm web:build
```
