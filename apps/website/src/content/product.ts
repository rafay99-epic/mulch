import type { InspectorData, PopoverData } from "@/content/types"

/** The menu bar popover, as it looks on a real Mac. */
export const popover = {
  reclaimable: "6.4 GB",
  bars: [
    { name: "Brave cache", size: "1.8 GB", fraction: 1 },
    { name: "Bun cache", size: "1.8 GB", fraction: 0.98 },
    { name: "Cursor snapshots", size: "679 MB", fraction: 0.37 },
    { name: "SwiftPM cache", size: "570 MB", fraction: 0.31 },
  ],
  inbox: [
    { name: "Old Android NDKs", size: "3.3 GB", path: "~/Library/Android/sdk/ndk/28.2" },
    { name: "Old Gradle versions", size: "957 MB", path: "~/.gradle/wrapper/dists/gradle-8.10" },
  ],
  stats: [
    { label: "Next sweep", value: "Sun 10:00" },
    { label: "Freed this month", value: "87.4 GB", accent: true },
    { label: "Disk free", value: "129 GB" },
  ],
} as const satisfies PopoverData

/** The main window: rules, items, and the inspector. */
export const inspector = {
  reclaimable: "4.8 GB",
  weekly: [
    { name: "Build output", size: "5.3 GB", selected: true },
    { name: "Dart analysis cache", size: "4.7 GB" },
    { name: "Brave cache", size: "1.8 GB" },
    { name: "Bun cache", size: "1.8 GB" },
    { name: "DerivedData", size: "1.7 GB" },
  ],
  asks: [
    { name: "Gradle caches", size: "8.2 GB" },
    { name: "Old Android NDKs", size: "3.3 GB" },
  ],
  rule: { title: "Build output", summary: "4 ready, 1.2 GB" },
  items: [
    { name: "echoes/apps/game/build", size: "3.7 GB", selected: true },
    { name: "Vitals/apps/desktop/.build", size: "442 MB" },
    { name: "Coppice/apps/desktop/.build", size: "328 MB" },
    { name: "wryte.xyz/apps/web/.next", size: "240 MB" },
    { name: "fvx/dist", size: "12 MB" },
  ],
  detail: {
    name: "build",
    path: "~/Code/echoes/apps/game/build",
    fields: [
      { label: "Size", value: "3.66 GB" },
      { label: "Last used", value: "19 days ago" },
      { label: "Why", value: "Project output, rebuilt by your tools, unused for 14+ days" },
      { label: "Status", value: "ready", accent: true },
    ],
  },
} as const satisfies InspectorData
