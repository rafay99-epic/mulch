import { site } from "@/lib/site"

export function Footer() {
  return (
    <footer className="mx-auto max-w-5xl px-6 py-10 text-sm text-muted-foreground">
      <a href={site.repo} className="hover:text-foreground">
        {site.name} on GitHub
      </a>
    </footer>
  )
}
