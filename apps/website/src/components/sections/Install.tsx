import { Section } from "@/components/sections/Section"
import { site } from "@/lib/site"

export function Install() {
  return (
    <Section id="install" title="Install">
      <pre className="overflow-x-auto rounded-lg border p-4 text-sm">
        <code>{site.install.join("\n")}</code>
      </pre>
    </Section>
  )
}
