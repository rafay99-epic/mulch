import type { Mode } from "@/content/types"

export interface Size {
  width: number
  height: number
}

/** Where a chip starts (scattered) and where it lands (its lane). Pixels and degrees. */
export interface ChipLayout {
  x0: number
  y0: number
  r0: number
  x1: number
  y1: number
}

export interface LaneHeader {
  mode: Mode
  x: number
  y: number
  width: number
}

export interface LanesLayout {
  headers: LaneHeader[]
  chips: ChipLayout[]
}

const LANE_ORDER: readonly Mode[] = ["auto", "ask", "never"]
/** Below this width the three lanes stack vertically instead of sitting side by side. */
const STACK_BELOW = 640

/** Small seeded PRNG so the scatter is identical on every render and every visit. */
function mulberry32(seed: number) {
  let a = seed
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/**
 * Lays out the "Everything gets a lane" scene: lane headers, a random scatter for each
 * chip, and its target slot. Wide screens get three columns side by side; narrow
 * screens stack the lanes, two chips per row.
 */
export function layoutLanes(modes: readonly Mode[], { width, height }: Size, seed = 11): LanesLayout {
  const random = mulberry32(seed)
  const gutter = width * 0.06
  const inner = width - gutter * 2
  const stacked = width < STACK_BELOW
  const chipWidth = stacked ? 140 : 190
  const counts = Object.fromEntries(LANE_ORDER.map((mode) => [mode, modes.filter((m) => m === mode).length])) as Record<Mode, number>

  const headers: LaneHeader[] = []
  const slotOrigin = {} as Record<Mode, { x: number; y: number }>
  if (stacked) {
    const headerHeight = 34
    const rowHeight = 30
    let y = height * 0.3
    for (const mode of LANE_ORDER) {
      headers.push({ mode, x: gutter, y, width: inner })
      slotOrigin[mode] = { x: gutter, y: y + headerHeight + 8 }
      y += headerHeight + 8 + Math.ceil(counts[mode] / 2) * rowHeight + 14
    }
  } else {
    const column = inner / LANE_ORDER.length
    LANE_ORDER.forEach((mode, i) => {
      headers.push({ mode, x: gutter + i * column, y: height * 0.27, width: column - 24 })
      slotOrigin[mode] = { x: gutter + i * column, y: height * 0.38 }
    })
  }

  const filled: Record<Mode, number> = { auto: 0, ask: 0, never: 0 }
  const chips = modes.map((mode) => {
    const slot = filled[mode]++
    const origin = slotOrigin[mode]
    return {
      x0: gutter + random() * Math.max(0, inner - chipWidth),
      y0: height * 0.3 + random() * height * 0.55,
      r0: (random() - 0.5) * 60,
      x1: stacked ? origin.x + (slot % 2) * (inner / 2) : origin.x,
      y1: stacked ? origin.y + Math.floor(slot / 2) * 30 : origin.y + slot * 40,
    }
  })
  return { headers, chips }
}
