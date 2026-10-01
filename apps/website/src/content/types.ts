// Shapes for everything the page renders. Content files `satisfies` these, so a
// typo or missing field fails the build instead of rendering a broken section.

export type Mode = "auto" | "ask" | "never"

/** Areas of the popover that the "How to use it" walkthrough highlights. */
export type PopoverPart = "num" | "clean" | "inbox" | "stats" | "open"

export type Href = `#${string}` | `https://${string}`

export interface NavLink {
  href: Href
  label: string
}

export interface LedgerItem {
  size: string
  name: string
  detail: string
}

export interface Step {
  title: string
  body: string
}

export interface WalkthroughStep extends Step {
  part: PopoverPart
}

export interface LaneItem {
  name: string
  mode: Mode
}

export interface Lane {
  mode: Mode
  label: string
  hint: string
}

export interface Stat {
  value: string
  label: string
}

export interface Site {
  name: string
  tagline: string
  summary: string
  repo: Href
  releases: Href
  latest: { tag: string; href: Href }
  requirements: string
  installCommand: readonly string[]
  nav: readonly NavLink[]
  hero: { title: readonly string[]; tags: readonly [string, string, string] }
  ledger: { total: string; caption: string; items: readonly LedgerItem[] }
  steps: { title: readonly [string, string]; items: readonly Step[] }
  walkthrough: { title: string; items: readonly WalkthroughStep[] }
  lanes: { title: string; lanes: readonly Lane[]; items: readonly LaneItem[]; closing: string }
  stats: readonly Stat[]
  install: { title: readonly [string, string] }
  footer: {
    columns: readonly { title: string; links: readonly NavLink[] }[]
    copyright: string
  }
}

// Product UI shown on the page, mirroring the real app.

export interface SizeRow {
  name: string
  size: string
}

export interface PopoverData {
  reclaimable: string
  bars: readonly (SizeRow & { fraction: number })[]
  inbox: readonly (SizeRow & { path: string })[]
  stats: readonly { label: string; value: string; accent?: boolean }[]
}

export interface InspectorData {
  reclaimable: string
  weekly: readonly (SizeRow & { selected?: boolean })[]
  asks: readonly SizeRow[]
  rule: { title: string; summary: string }
  items: readonly (SizeRow & { selected?: boolean })[]
  detail: { name: string; path: string; fields: readonly { label: string; value: string; accent?: boolean }[] }
}
