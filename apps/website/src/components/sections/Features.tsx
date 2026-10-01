import { Reveal } from "@/components/motion/Reveal"
import { Section } from "@/components/sections/Section"
import { site } from "@/lib/site"

export function Features() {
  return (
    <Section id="features" title="Features">
      <ul className="grid gap-8 md:grid-cols-3">
        {site.features.map((feature, index) => (
          <li key={feature.title}>
            <Reveal delay={index * 0.05}>
              <h3 className="font-medium">{feature.title}</h3>
              <p className="mt-2 text-muted-foreground">{feature.body}</p>
            </Reveal>
          </li>
        ))}
      </ul>
    </Section>
  )
}
