import type { ReactNode } from "react"
import { cn } from "@/lib/utils"

type SectionProps = {
  id: string
  title?: string
  children: ReactNode
  className?: string
}

/** Shared section frame: anchor id, width and spacing. */
export function Section({ id, title, children, className }: SectionProps) {
  return (
    <section id={id} aria-labelledby={title ? `${id}-title` : undefined} className={cn("mx-auto max-w-5xl px-6 py-20", className)}>
      {title && (
        <h2 id={`${id}-title`} className="mb-8 text-2xl font-semibold">
          {title}
        </h2>
      )}
      {children}
    </section>
  )
}
