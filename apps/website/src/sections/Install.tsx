import { Reveal } from "@/components/motion/Reveal"
import { site } from "@/content/site"
import { useCopy } from "@/hooks/useCopy"

export function Install() {
  const { copied, copy } = useCopy()
  const command = site.installCommand.join(" && ")

  return (
    <section id="install" className="mx-auto max-w-[1400px] scroll-mt-14 px-[clamp(20px,8vw,140px)] py-[16vh]">
      <Reveal>
        <h2 className="text-center font-serif text-[clamp(48px,6.4vw,104px)] leading-[0.98]">
          {site.install.title[0]}
          <br />
          <em className="text-leaf">{site.install.title[1]}</em>
        </h2>
      </Reveal>
      <Reveal className="mx-auto mt-14 max-w-[860px]">
        <div className="relative rounded-[14px] border border-frame bg-panel">
          <pre className="whitespace-pre-wrap break-all px-5 pb-5 pt-14 font-mono text-sm leading-[1.8] sm:overflow-x-auto sm:whitespace-pre sm:break-normal sm:px-7 sm:py-6 sm:pr-28 sm:text-base">
            <code>{site.installCommand.join("\n")}</code>
          </pre>
          <button
            type="button"
            onClick={() => void copy(command)}
            className="absolute right-4 top-4 rounded-full bg-white px-3.5 py-1.5 text-[13px] font-semibold text-black transition-colors hover:bg-white/85"
          >
            {copied ? "Copied" : "Copy"}
          </button>
        </div>
        <p className="mt-4 flex flex-wrap justify-center gap-x-7 gap-y-2 text-sm text-muted-foreground">
          <span>{site.requirements}</span>
          <span>
            Latest{" "}
            <a href={site.latest.href} className="text-leaf hover:underline">
              {site.latest.tag}
            </a>
          </span>
          <a href={site.repo} className="text-leaf hover:underline">
            Build from source
          </a>
        </p>
      </Reveal>
    </section>
  )
}
