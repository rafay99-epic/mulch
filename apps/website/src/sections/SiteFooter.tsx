import { Leaf } from "@/components/brand/Brand"
import { site } from "@/content/site"

export function SiteFooter() {
  return (
    <footer className="mt-[10vh] border-t border-line px-[clamp(20px,6vw,96px)] pb-9 pt-[72px]">
      <div className="grid gap-10 md:grid-cols-[2fr_1fr_1fr_1fr]">
        <div className="flex flex-col gap-2.5">
          <Leaf />
          <b className="text-[22px]">{site.name}</b>
          <p className="max-w-[300px] text-muted-foreground">{site.tagline}</p>
        </div>
        {site.footer.columns.map((column) => (
          <nav key={column.title} aria-label={column.title} className="flex flex-col gap-2.5 text-sm text-muted-foreground">
            <h3 className="mb-1 font-semibold text-foreground">{column.title}</h3>
            {column.links.map((link) => (
              <a key={link.href} href={link.href} className="transition-colors hover:text-foreground">
                {link.label}
              </a>
            ))}
          </nav>
        ))}
      </div>
      <div className="mt-16 flex justify-between border-t border-line pt-5 text-[13px] text-neutral-500">
        <span>{site.footer.copyright}</span>
        <span>{site.requirements}</span>
      </div>
    </footer>
  )
}
