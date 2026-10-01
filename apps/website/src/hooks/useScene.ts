import { useScroll } from "motion/react"
import { useRef } from "react"

/**
 * Progress through a pinned scene: 0 when the section's top reaches the top of the
 * viewport, 1 when its bottom reaches the bottom. Pair with a `sticky top-0 h-svh`
 * child inside a section taller than the viewport.
 */
export function useScene<T extends HTMLElement = HTMLElement>() {
  const ref = useRef<T>(null)
  const { scrollYProgress: progress } = useScroll({ target: ref, offset: ["start start", "end end"] })
  return { ref, progress }
}
