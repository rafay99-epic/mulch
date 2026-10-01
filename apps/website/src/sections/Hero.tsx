import { m } from "motion/react"
import { GithubMark } from "@/components/brand/Brand"
import { InspectorWindow } from "@/components/product/InspectorWindow"
import { inspector } from "@/content/product"
import { site } from "@/content/site"
import { useHeroMotion } from "@/hooks/scenes"
import { useScene } from "@/hooks/useScene"

const TAG_POSITIONS = ["left-[2%]", "left-[36%]", "left-[70%]"] as const
const TAG_DEPTHS = [50, 100, 150] as const

// The window is drawn at 1000x520 and scaled per breakpoint, in CSS so the prerendered
// HTML is already the right size. Tag text is counter-sized to read at about 13px.
const WINDOW_SCALE =
  "scale-[.37] min-[480px]:scale-[.46] sm:scale-[.62] md:scale-[.76] lg:scale-[.92] xl:scale-100"
const TAG_SIZE = "text-[36px] min-[480px]:text-[30px] sm:text-[22px] md:text-[18px] lg:text-[15px] xl:text-sm"

/** Name, purpose, and the app window that comes apart in 3D, then exits. */
export function Hero() {
  const { ref, progress } = useScene<HTMLElement>()
  const motion = useHeroMotion(progress)

  return (
    <section ref={ref} id="top" className="relative h-[290vh]">
      <div className="sticky top-0 h-svh overflow-hidden">
        <m.div style={motion.copy} className="mx-auto max-w-[980px] px-6 pt-[calc(3.5rem+8vh)] text-center">
          <h1 className="font-serif text-[clamp(56px,8vw,128px)] leading-[0.95] tracking-[-0.02em]">
            {site.hero.title[0]}
            <br />
            {site.hero.title[1]}
          </h1>
          <p className="mx-auto mt-6 max-w-[720px] text-[clamp(18px,1.6vw,22px)] text-muted-foreground">{site.summary}</p>
          <div className="mt-9 flex items-center justify-center gap-7">
            <a href="#install" className="rounded-full bg-white px-7 py-3.5 text-[17px] font-semibold text-black transition-colors hover:bg-white/85">
              Install Mulch
            </a>
            <a href={site.repo} className="flex items-center gap-2 font-medium transition-colors hover:text-leaf">
              <GithubMark /> View on GitHub
            </a>
          </div>
        </m.div>

        <div className="absolute inset-x-0 bottom-[4vh] flex justify-center">
          <div className={`origin-bottom perspective-[1600px] ${WINDOW_SCALE}`}>
            <m.div style={motion.rig} className="relative transform-3d">
              <InspectorWindow data={inspector} depth={motion.depth} />
              {site.hero.tags.map((tag, i) => (
                <m.span
                  key={tag}
                  style={{ opacity: motion.tags.opacity, z: TAG_DEPTHS[i] }}
                  className={`absolute -bottom-[2.2em] whitespace-nowrap font-mono font-semibold text-leaf ${TAG_SIZE} ${TAG_POSITIONS[i]}`}
                >
                  {tag}
                </m.span>
              ))}
            </m.div>
          </div>
        </div>
      </div>
    </section>
  )
}
