import { Reveal } from "@/components/motion/Reveal"
import { site } from "@/content/site"

export function Stats() {
  return (
    <section aria-label="Lightweight" className="mx-auto grid max-w-[1400px] gap-5 px-[clamp(20px,8vw,140px)] py-[16vh] text-center md:grid-cols-3">
      {site.stats.map((stat, i) => (
        <Reveal key={stat.label} delay={i * 0.05}>
          <b className="block whitespace-nowrap font-display text-[clamp(72px,9vw,160px)] leading-[0.9]">{stat.value}</b>
          <span className="text-lg text-muted-foreground">{stat.label}</span>
        </Reveal>
      ))}
    </section>
  )
}
