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

const LANE_ORDER: readonly Mode[] = ["auto", "ask", "never"]

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
 * Lays chips out for the "Everything gets a lane" scene: a random scatter over the
 * lower part of the stage, and a target slot in the chip's lane column.
 */
export function layoutLanes(modes: readonly Mode[], { width, height }: Size, seed = 11): ChipLayout[] {
  const random = mulberry32(seed)
  const gutter = width * 0.06
  const column = (width - gutter * 2) / LANE_ORDER.length
  const filled: Record<Mode, number> = { auto: 0, ask: 0, never: 0 }
  return modes.map((mode) => {
    const slot = filled[mode]++
    return {
      x0: gutter + random() * (width - gutter * 3),
      y0: height * 0.3 + random() * height * 0.55,
      r0: (random() - 0.5) * 60,
      x1: gutter + LANE_ORDER.indexOf(mode) * column,
      y1: height * 0.38 + slot * 40,
    }
  })
}
