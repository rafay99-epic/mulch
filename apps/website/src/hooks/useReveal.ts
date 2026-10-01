import { useReducedMotion, useScroll, useTransform } from "motion/react"
import { useRef } from "react"

/**
 * Enter and exit motion for an element in normal flow: it fades and rises in as it
 * enters the viewport and drifts up and out as it leaves. `delay` (0..0.2) staggers
 * siblings. Returns nothing to animate when the user prefers reduced motion.
 */
export function useReveal<T extends HTMLElement = HTMLDivElement>(delay = 0) {
  const ref = useRef<T>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] })
  const range = [delay, delay + 0.2, 0.78, 1]
  const opacity = useTransform(scrollYProgress, range, [0, 1, 1, 0])
  const y = useTransform(scrollYProgress, range, [60, 0, 0, -40])
  return { ref, style: reduce ? undefined : { opacity, y } }
}
