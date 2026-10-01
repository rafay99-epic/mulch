import { Popover } from "@/components/product/Popover"
import { popover } from "@/content/product"
import { site } from "@/content/site"
import { useScene } from "@/hooks/useScene"
import { useStep } from "@/hooks/useStep"
import { cn } from "@/lib/utils"

/**
 * The popover stays pinned while each of its parts is explained in turn. Phones show
 * the active step above a scaled popover; wider screens list every step beside it.
 */
export function HowToUse() {
  const { ref, progress } = useScene<HTMLElement>()
  const steps = site.walkthrough.items
  const step = useStep(progress, steps.length)

  return (
    <section ref={ref} id="use" className="relative h-[480vh]">
      <div className="sticky top-0 flex h-svh flex-col justify-center overflow-hidden px-[clamp(20px,8vw,140px)] pt-14 md:grid md:grid-cols-2 md:items-center md:gap-[6vw]">
        <div>
          <h2 className="mb-4 font-serif text-[clamp(40px,5vw,80px)] leading-none md:mb-8">{site.walkthrough.title}</h2>
          <ol>
            {steps.map((item, i) => (
              <li
                key={item.part}
                aria-current={i === step ? "step" : undefined}
                className={cn(
                  "border-t border-line py-3 transition-colors duration-300",
                  i === step ? "text-foreground" : "text-neutral-500 max-md:hidden",
                )}
              >
                <b className={cn("font-mono text-[13px] font-semibold", i === step && "text-leaf")}>
                  {String(i + 1).padStart(2, "0")} {item.title}
                </b>
                <p className="mt-1.5 text-lg leading-snug md:text-[22px]">{item.body}</p>
              </li>
            ))}
          </ol>
        </div>
        <div className="-my-14 grid place-items-center md:my-0">
          <Popover data={popover} active={steps[step]?.part} className="scale-[.78] min-[400px]:scale-[.84] md:scale-[1.18]" />
        </div>
      </div>
    </section>
  )
}
