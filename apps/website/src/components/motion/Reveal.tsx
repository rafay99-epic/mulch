import { m } from "motion/react"
import type { ReactNode } from "react"
import { useReveal } from "@/hooks/useReveal"

interface RevealProps {
  children: ReactNode
  /** Stagger offset, 0..0.2. */
  delay?: number
  className?: string
}

/** Fades and rises in on enter, drifts out on exit. */
export function Reveal({ children, delay = 0, className }: RevealProps) {
  const { ref, style } = useReveal(delay)
  return (
    <m.div ref={ref} style={style} className={className}>
      {children}
    </m.div>
  )
}
