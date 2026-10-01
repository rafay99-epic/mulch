import { type MotionValue, useMotionValueEvent } from "motion/react"
import { useState } from "react"

/** Splits 0..1 progress into `count` equal steps. Re-renders only when the step changes. */
export function useStep(progress: MotionValue<number>, count: number) {
  const toStep = (p: number) => Math.min(count - 1, Math.max(0, Math.floor(p * count)))
  const [step, setStep] = useState(() => toStep(progress.get()))
  useMotionValueEvent(progress, "change", (p) => setStep(toStep(p)))
  return step
}
