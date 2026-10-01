import type { Site } from "@/content/types"

const repo = "https://github.com/rafay99-epic/mulch"

/** All page copy and numbers. Numbers come from a real Mac on 2026-10-01. */
export const site = {
  name: "Mulch",
  tagline: "The dev junk on your Mac, cleared every Sunday.",
  summary:
    "Mulch lives in your menu bar and clears the build output, caches and leftovers your dev tools pile up, once a week, while your Mac is idle.",
  repo,
  releases: `${repo}/releases`,
  latest: { tag: "v3", href: `${repo}/releases/tag/v3` },
  requirements: "macOS 26+, Apple silicon",
  installCommand: ["gh repo clone rafay99-epic/mulch ~/Code/mulch", "~/Code/mulch/apps/desktop/Scripts/install-release.sh"],
  nav: [
    { href: "#how", label: "How it works" },
    { href: "#use", label: "How to use" },
    { href: "#safety", label: "Safety" },
    { href: "#install", label: "Install" },
  ],
  hero: {
    title: ["Your Mac,", "cleared every Sunday."],
    tags: ["Rules, with sizes", "Everything it found", "Why it is safe"],
  },
  ledger: {
    total: "95",
    caption: "back on one Mac, in one sweep.",
    items: [
      { size: "40 GB", name: "Build output", detail: "~/Code/**/build" },
      { size: "32 GB", name: "Chrome leftovers", detail: "24 old copies" },
      { size: "16 GB", name: "Gradle caches", detail: "~/.gradle/caches" },
      { size: "10 GB", name: "Cursor snapshots", detail: "restore points" },
      { size: "9.6 GB", name: "Docker images", detail: "unused" },
      { size: "6 GB", name: "App caches", detail: "~/Library/Caches" },
      { size: "0 GB", name: "Your work", detail: "untouched" },
    ],
  },
  steps: {
    title: ["Three steps.", "Then nothing."],
    items: [
      { title: "Install", body: "One command per Mac. It lands in your menu bar as a small leaf." },
      { title: "First scan", body: "It finds your code folders and tools, and shows what the first sweep will clear before anything goes." },
      { title: "Forget it", body: "Every Sunday, when your Mac is idle and on power, it sweeps. One quiet notification, only if something needs you." },
    ],
  },
  walkthrough: {
    title: "How to use it",
    items: [
      { part: "num", title: "The number", body: "What Mulch can free right now." },
      { part: "clean", title: "Clean", body: "Clears every Auto rule in one go, if you do not want to wait for Sunday." },
      { part: "inbox", title: "Needs you", body: "Riskier finds wait here. Clean or Skip." },
      { part: "stats", title: "The schedule", body: "When the next sweep runs, and what the last ones freed." },
      { part: "open", title: "Open Mulch", body: "Every rule, every path, and why each one is safe to remove." },
    ],
  },
  lanes: {
    title: "Everything gets a lane.",
    lanes: [
      { mode: "auto", label: "Auto", hint: "cleared weekly" },
      { mode: "ask", label: "Ask", hint: "waits for you" },
      { mode: "never", label: "Never", hint: "off limits" },
    ],
    items: [
      { name: "Build output", mode: "auto" },
      { name: "Chrome leftovers", mode: "auto" },
      { name: "Cursor caches", mode: "auto" },
      { name: "npm cache", mode: "auto" },
      { name: "DerivedData", mode: "auto" },
      { name: "Bun cache", mode: "auto" },
      { name: "Docker images", mode: "ask" },
      { name: "Old NDKs", mode: "ask" },
      { name: "Gradle caches", mode: "ask" },
      { name: "Device support", mode: "ask" },
      { name: "T3 worktrees", mode: "never" },
      { name: "Emulators", mode: "never" },
      { name: "Simulators", mode: "never" },
      { name: "Your folders", mode: "never" },
    ],
    closing: "And every item is checked again right before it goes.",
  },
  stats: [
    { value: "28 MB", label: "of memory" },
    { value: "0%", label: "CPU between sweeps" },
    { value: "0", label: "terminal commands" },
  ],
  install: { title: ["Install it once.", "Get your weekends back."] },
  footer: {
    columns: [
      {
        title: "Product",
        links: [
          { href: "#how", label: "How it works" },
          { href: "#use", label: "How to use" },
          { href: "#safety", label: "Safety" },
          { href: "#install", label: "Install" },
        ],
      },
      {
        title: "Source",
        links: [
          { href: repo, label: "GitHub" },
          { href: `${repo}/releases`, label: "Releases" },
          { href: `${repo}/issues`, label: "Report an issue" },
        ],
      },
      {
        title: "Family",
        links: [
          { href: "https://github.com/rafay99-epic/Coppice", label: "Coppice" },
          { href: "https://rafay99.com", label: "rafay99.com" },
        ],
      },
    ],
    copyright: "2026 Abdul Rafay",
  },
} as const satisfies Site
