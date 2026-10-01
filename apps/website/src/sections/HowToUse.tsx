import { Popover } from "@/components/product/Popover"
import { popover } from "@/content/product"
import { site } from "@/content/site"
import { useScene } from "@/hooks/useScene"
import { useStep } from "@/hooks/useStep"
import { cn } from "@/lib/utils"

/** The popover stays pinned while each of its parts is explained in turn. */
export function HowToUse() {
  const { ref, progress } = useScene<HTMLElement>()
  const steps = site.walkthrough.items
  const step = useStep(progress, steps.length)

  return (
    <section ref={ref} id="use" className="relative h-[480vh]">
      <div className="sticky top-0 grid h-svh items-center gap-[6vw] overflow-hidden px-[clamp(20px,8vw,140px)] pt-14 md:grid-cols-2">
        <div>
          <h2 className="mb-8 font-serif text-[clamp(44px,5vw,80px)] leading-none">{site.walkthrough.title}</h2>
          <ol>
            {steps.map((item, i) => (
              <li
                key={item.part}
                aria-current={i === step ? "step" : undefined}
                className={cn("border-t border-line py-3 transition-colors duration-300", i === step ? "text-foreground" : "text-neutral-500")}
              >
                <b className={cn("font-mono text-[13px] font-semibold", i === step && "text-leaf")}>
                  {String(i + 1).padStart(2, "0")} {item.title}
                </b>
                <p className="mt-1.5 text-[22px] leading-snug">{item.body}</p>
              </li>
            ))}
          </ol>
        </div>
        <div className="hidden place-items-center md:grid">
          <Popover data={popover} active={steps[step]?.part} className="scale-[1.18]" />
        </div>
      </div>
    </section>
  )
}
