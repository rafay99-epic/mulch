import { m, type MotionValue, useTransform } from "motion/react"
import { useMemo, useRef } from "react"
import type { Mode } from "@/content/types"
import { site } from "@/content/site"
import { useLanesMotion } from "@/hooks/scenes"
import { useElementSize } from "@/hooks/useElementSize"
import { useScene } from "@/hooks/useScene"
import { type ChipLayout, layoutLanes } from "@/lib/lanes"
import { cn } from "@/lib/utils"

const MODE_COLOR: Record<Mode, string> = { auto: "bg-leaf", ask: "bg-ask", never: "bg-never" }

/** Safety: scattered finds sort themselves into Auto, Ask and Never. */
export function Lanes() {
  const { ref, progress } = useScene<HTMLElement>()
  const motion = useLanesMotion(progress)
  const stage = useRef<HTMLDivElement>(null)
  const size = useElementSize(stage)
  const { items, lanes } = site.lanes
  const layout = useMemo(() => (size.width ? layoutLanes(items.map((item) => item.mode), size) : undefined), [items, size])

  return (
    <section ref={ref} id="safety" className="relative h-[280vh]">
      <div ref={stage} className="sticky top-0 h-svh overflow-hidden px-[6vw] pt-[calc(3.5rem+6vh)]">
        <h2 className="text-center font-serif text-[clamp(44px,6.4vw,104px)] leading-[0.98]">{site.lanes.title}</h2>
        {layout?.headers.map((header) => {
          const lane = lanes.find((l) => l.mode === header.mode)
          return lane ? (
            <div
              key={header.mode}
              style={{ left: header.x, top: header.y, width: header.width }}
              className="absolute flex items-center gap-3 border-b border-line pb-2 font-serif text-[clamp(24px,2.6vw,38px)] leading-none"
            >
              <i className={cn("size-3 rounded-full", MODE_COLOR[lane.mode])} />
              {lane.label}
              <small className="ml-1.5 font-mono text-[13px] text-muted-foreground">{lane.hint}</small>
            </div>
          ) : null
        })}
        <ul aria-label="Examples by lane" className="pointer-events-none absolute inset-0">
          {layout?.chips.map((chip, i) => {
            const item = items[i]
            return item ? <Chip key={item.name} name={item.name} mode={item.mode} layout={chip} sorted={motion.sorted} /> : null
          })}
        </ul>
        <m.p
          style={motion.closing}
          className="absolute inset-x-[6vw] bottom-[7vh] text-center font-serif text-[clamp(22px,2vw,30px)] text-muted-foreground"
        >
          {site.lanes.closing}
        </m.p>
      </div>
    </section>
  )
}

function Chip({ name, mode, layout, sorted }: { name: string; mode: Mode; layout: ChipLayout; sorted: MotionValue<number> }) {
  const x = useTransform(sorted, (t) => layout.x0 + (layout.x1 - layout.x0) * t)
  const y = useTransform(sorted, (t) => layout.y0 + (layout.y1 - layout.y0) * t)
  const rotate = useTransform(sorted, (t) => layout.r0 * (1 - t))
  return (
    <m.li
      style={{ x, y, rotate }}
      className="absolute left-0 top-0 flex items-center gap-2 whitespace-nowrap py-1 font-mono text-[13px] sm:py-1.5 sm:text-[15px]"
    >
      <i className={cn("h-3 w-4 flex-none rounded-[3px] sm:h-3.5 sm:w-[18px]", MODE_COLOR[mode])} />
      {name}
    </m.li>
  )
}
