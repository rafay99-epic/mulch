import { Reveal } from "@/components/motion/Reveal"
import { Section } from "@/components/sections/Section"
import { buttonVariants } from "@/components/ui/button"
import { site } from "@/lib/site"

export function Hero() {
  return (
    <Section id="top">
      <Reveal>
        <h1 className="text-5xl font-semibold">{site.name}</h1>
        <p className="mt-4 text-lg">{site.tagline}</p>
        <a href="#install" className={buttonVariants({ className: "mt-8" })}>
          Install
        </a>
      </Reveal>
    </Section>
  )
}
