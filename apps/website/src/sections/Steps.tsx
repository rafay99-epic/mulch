import { Reveal } from "@/components/motion/Reveal"
import { site } from "@/content/site"

export function Steps() {
  return (
    <section id="how" className="mx-auto max-w-[1400px] scroll-mt-14 px-[clamp(20px,8vw,140px)] py-[16vh]">
      <Reveal>
        <h2 className="text-center font-serif text-[clamp(48px,6.4vw,104px)] leading-[0.98] tracking-[-0.01em]">
          {site.steps.title[0]}
          <br />
          <em className="text-leaf">{site.steps.title[1]}</em>
        </h2>
      </Reveal>
      <ol className="mt-20 grid gap-12 md:grid-cols-3">
        {site.steps.items.map((step, i) => (
          <li key={step.title}>
            <Reveal delay={i * 0.06}>
              <b className="mb-5 block font-display text-[120px] leading-[0.8] text-leaf">{i + 1}</b>
              <h3 className="text-[26px] font-semibold">{step.title}</h3>
              <p className="mt-2.5 text-muted-foreground">{step.body}</p>
            </Reveal>
          </li>
        ))}
      </ol>
    </section>
  )
}
