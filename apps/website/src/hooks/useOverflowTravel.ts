import { useMotionValue } from "motion/react"
import { type RefObject, useLayoutEffect } from "react"

/**
 * How far `content` must slide left so its end lands inside `frame` (keeping
 * `inset` of the frame's width free on the right). A MotionValue, so resizes never
 * re-render. Used to slide a row of items fully into view at any screen width.
 */
export function useOverflowTravel(content: RefObject<HTMLElement | null>, frame: RefObject<HTMLElement | null>, inset = 0.1) {
  const travel = useMotionValue(0)
  useLayoutEffect(() => {
    const contentNode = content.current
    const frameNode = frame.current
    if (!contentNode || !frameNode) return
    const update = () => travel.set(Math.max(0, contentNode.offsetLeft + contentNode.scrollWidth - frameNode.clientWidth * (1 - inset)))
    const observer = new ResizeObserver(update)
    observer.observe(contentNode)
    observer.observe(frameNode)
    return () => observer.disconnect()
  }, [content, frame, travel, inset])
  return travel
}
