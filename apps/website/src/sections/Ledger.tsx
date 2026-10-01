import { m, type MotionValue, useTransform } from "motion/react"
import { useRef } from "react"
import { site } from "@/content/site"
import { useLedgerMotion } from "@/hooks/scenes"
import { useOverflowTravel } from "@/hooks/useOverflowTravel"
import { useScene } from "@/hooks/useScene"

/**
 * "95 GB back": huge numerals track apart while the items slide past. It overlaps the
 * hero by 80vh so it rises over the window as the window exits.
 */
export function Ledger() {
  const { ref, progress } = useScene<HTMLElement>()
  const stage = useRef<HTMLDivElement>(null)
  const strip = useRef<HTMLUListElement>(null)
  const motion = useLedgerMotion(progress, useOverflowTravel(strip, stage))
  const glyphs = [...`${site.ledger.total}GB`]

  return (
    <section ref={ref} aria-labelledby="ledger-title" className="relative z-10 -mt-[80vh] h-[250vh]">
      <h2 id="ledger-title" className="sr-only">
        {site.ledger.total} GB {site.ledger.caption}
      </h2>
      <div ref={stage} className="sticky top-0 h-svh overflow-hidden">
        <m.div
          aria-hidden="true"
          style={{ scaleY: motion.scaleY }}
          className="absolute left-[5vw] top-[calc(3.5rem+2vh)] flex origin-top-left whitespace-nowrap font-display text-[clamp(160px,30vw,420px)] leading-[0.82]"
        >
          {glyphs.map((char, i) => (
            <Glyph key={i} index={i} spread={motion.spread} green={i >= site.ledger.total.length}>
              {char}
            </Glyph>
          ))}
        </m.div>
        <m.p
          aria-hidden="true"
          style={{ clipPath: motion.caption }}
          className="absolute left-[5.4vw] right-[5vw] top-[42vh] font-serif text-[clamp(36px,4.6vw,76px)] italic leading-[1.05] sm:top-[50vh] sm:whitespace-nowrap"
        >
          {site.ledger.caption}
        </m.p>
        <m.ul ref={strip} style={{ x: motion.strip }} className="absolute bottom-[7vh] left-[5vw] flex">
          {site.ledger.items.map((item) => (
            <li key={item.name} className="w-[210px] flex-none border-l border-frame px-5 sm:w-[300px] sm:px-6">
              <b className="block font-display text-[44px] leading-none sm:text-[54px]">{item.size}</b>
              <span className="mt-2 block font-mono text-sm text-muted-foreground">{item.name}</span>
              <span className="font-mono text-[13px] text-leaf">{item.detail}</span>
            </li>
          ))}
        </m.ul>
      </div>
    </section>
  )
}

/** One numeral, pushed right by `spread` (vw) times its index: tracking via transforms. */
function Glyph({ index, spread, green, children }: { index: number; spread: MotionValue<number>; green: boolean; children: string }) {
  const x = useTransform(spread, (v) => `${v * index}vw`)
  return (
    <m.span style={{ x }} className={green ? "inline-block text-leaf" : "inline-block"}>
      {children}
    </m.span>
  )
}
