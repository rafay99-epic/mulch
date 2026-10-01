import { domAnimation, LazyMotion } from "motion/react"
import type { ReactNode } from "react"

/** Loads only the DOM animation features. Components use `m.*`, not `motion.*`. */
export function MotionProvider({ children }: { children: ReactNode }) {
  return (
    <LazyMotion features={domAnimation} strict>
      {children}
    </LazyMotion>
  )
}
