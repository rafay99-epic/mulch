import { m, type MotionValue, useTransform } from "motion/react"
import { site } from "@/content/site"
import { useLedgerMotion } from "@/hooks/scenes"
import { useScene } from "@/hooks/useScene"

/**
 * "95 GB back": huge numerals track apart while the items slide past. It overlaps the
 * hero by 80vh so it rises over the window as the window exits.
 */
export function Ledger() {
  const { ref, progress } = useScene<HTMLElement>()
  const motion = useLedgerMotion(progress)
  const glyphs = [...`${site.ledger.total}GB`]

  return (
    <section ref={ref} aria-labelledby="ledger-title" className="relative z-10 -mt-[80vh] h-[250vh]">
      <h2 id="ledger-title" className="sr-only">
        {site.ledger.total} GB {site.ledger.caption}
      </h2>
      <div className="sticky top-0 h-svh overflow-hidden">
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
          className="absolute left-[5.4vw] top-[50vh] whitespace-nowrap font-serif text-[clamp(36px,4.6vw,76px)] italic leading-none"
        >
          {site.ledger.caption}
        </m.p>
        <m.ul style={{ x: motion.strip }} className="absolute bottom-[7vh] left-[5vw] flex">
          {site.ledger.items.map((item) => (
            <li key={item.name} className="w-[300px] flex-none border-l border-frame px-6">
              <b className="block font-display text-[54px] leading-none">{item.size}</b>
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
