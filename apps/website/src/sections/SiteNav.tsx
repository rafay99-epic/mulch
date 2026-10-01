import { m, useScroll } from "motion/react"
import { GithubMark, Leaf } from "@/components/brand/Brand"
import { site } from "@/content/site"

export function SiteNav() {
  const { scrollYProgress } = useScroll()
  return (
    <header className="fixed inset-x-0 top-0 z-50">
      <nav aria-label="Main" className="flex h-14 items-center gap-8 border-b border-line bg-black/85 px-[clamp(20px,4vw,48px)]">
        <a href="#top" className="flex items-center gap-2 text-lg font-bold">
          <Leaf />
          {site.name}
        </a>
        <div className="hidden gap-6 text-sm text-muted-foreground md:flex">
          {site.nav.map((link) => (
            <a key={link.href} href={link.href} className="transition-colors hover:text-foreground">
              {link.label}
            </a>
          ))}
        </div>
        <div className="ml-auto flex items-center gap-5 text-sm">
          <a href={site.repo} aria-label="Mulch on GitHub" className="flex items-center gap-2 text-muted-foreground transition-colors hover:text-foreground">
            <GithubMark />
            <span className="hidden sm:inline">GitHub</span>
          </a>
          <a href="#install" className="rounded-full bg-white px-4 py-2 font-semibold text-black transition-colors hover:bg-white/85">
            Install
          </a>
        </div>
      </nav>
      <m.div aria-hidden="true" style={{ scaleX: scrollYProgress }} className="h-0.5 origin-left bg-leaf" />
    </header>
  )
}
