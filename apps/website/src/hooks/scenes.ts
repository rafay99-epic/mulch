import { easeInOut, type MotionValue, useReducedMotion, useTransform } from "motion/react"

const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1)

/**
 * Hero: the window rises and explodes into layers as one eased motion (`depth`),
 * holds, then shrinks and fades (`exit`) while the next scene scrolls up over it.
 */
export function useHeroMotion(progress: MotionValue<number>) {
  const reduce = useReducedMotion()
  const depth = useTransform(progress, [0.03, 0.4], [0, 1], { ease: easeInOut })
  const exit = useTransform(progress, [0.58, 0.96], [0, 1])
  const rig = {
    y: useTransform(() => `${(1 - depth.get()) * 40 - depth.get() * 3 - exit.get() * 12}vh`),
    rotateX: useTransform(depth, [0, 1], [0, 46]),
    rotateZ: useTransform(depth, [0, 1], [0, -22]),
    scale: useTransform(() => 0.9 + depth.get() * 0.04 - exit.get() * 0.42),
    opacity: useTransform(exit, [0, 1], [1, 0]),
  }
  return {
    depth,
    copy: {
      opacity: useTransform(depth, [0, 0.38], [1, 0]),
      y: useTransform(depth, [0, 0.38], [0, -60]),
    },
    // Reduced motion: the window stays flat and in place; the page still scrolls normally.
    rig: reduce ? undefined : rig,
    tags: { opacity: useTransform(() => Math.min(clamp01((depth.get() - 0.55) * 3), 1 - exit.get() * 2)) },
  }
}

/**
 * Ledger: the big number tracks out, the caption wipes in, and the items slide left
 * by `travel` pixels, so the last one ends in view at any width.
 */
export function useLedgerMotion(progress: MotionValue<number>, travel: MotionValue<number>) {
  return {
    spread: useTransform(progress, [0, 1], [0, 6]),
    scaleY: useTransform(progress, [0, 1], [1, 1.25]),
    caption: useTransform(progress, [0.15, 0.48], ["inset(0 100% 0 0)", "inset(0 0% 0 0)"]),
    strip: useTransform(() => -progress.get() * travel.get()),
  }
}

/** Lanes: chips sort from scatter to lanes, then the closing line fades in. */
export function useLanesMotion(progress: MotionValue<number>) {
  return {
    sorted: useTransform(progress, [0.12, 0.54], [0, 1], { ease: easeInOut }),
    closing: {
      opacity: useTransform(progress, [0.62, 0.86], [0, 1]),
      y: useTransform(progress, [0.62, 0.86], [20, 0]),
    },
  }
}
