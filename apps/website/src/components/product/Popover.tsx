import type { ReactNode } from "react"
import type { PopoverData, PopoverPart } from "@/content/types"
import { cn } from "@/lib/utils"

interface PopoverProps {
  data: PopoverData
  /** Outlines one area in brand green. */
  active?: PopoverPart
  className?: string
}

/** The menu bar popover, rebuilt in HTML so parts can be highlighted. */
export function Popover({ data, active, className }: PopoverProps) {
  const part = (name: PopoverPart, children: ReactNode, extra?: string) => (
    <div
      className={cn(
        "rounded-md outline-2 outline-offset-4 outline-transparent transition-[outline-color] duration-300",
        active === name && "outline-leaf",
        extra,
      )}
    >
      {children}
    </div>
  )

  return (
    <div className={cn("flex w-[340px] flex-col gap-3.5 rounded-2xl border border-frame bg-black p-4 text-[13px]", className)}>
      {part(
        "num",
        <>
          <b className="block text-[42px] font-semibold leading-none tabular-nums">{data.reclaimable}</b>
          <span className="text-muted-foreground">Reclaimable now</span>
        </>,
      )}
      <div className="grid gap-1">
        {data.bars.map((bar) => (
          <div key={bar.name}>
            <div className="flex justify-between">
              <span>{bar.name}</span>
              <span>{bar.size}</span>
            </div>
            <div className="mb-1.5 mt-1 h-[5px] rounded-full bg-line">
              <div className="h-full rounded-full bg-white" style={{ width: `${bar.fraction * 100}%` }} />
            </div>
          </div>
        ))}
      </div>
      {part("clean", <div className="rounded-[10px] bg-leaf p-2.5 text-center font-semibold text-black">Clean {data.reclaimable}</div>)}
      {part(
        "inbox",
        <>
          <b>
            Needs you <span className="ml-1 text-ask">{data.inbox.length}</span>
          </b>
          {data.inbox.map((item) => (
            <div key={item.name} className="mt-2 flex items-center gap-2">
              <span className="flex flex-1 flex-col">
                {item.name}
                <small className="text-[10px] text-neutral-500">{item.path}</small>
              </span>
              <span>{item.size}</span>
              <span className="rounded-md bg-leaf px-2 py-0.5 text-[11px] font-semibold text-black">Clean</span>
              <span className="text-[11px] text-muted-foreground">Skip</span>
            </div>
          ))}
        </>,
      )}
      {part(
        "stats",
        data.stats.map((stat) => (
          <div key={stat.label} className="flex justify-between">
            <span>{stat.label}</span>
            <span className={cn(stat.accent && "text-leaf")}>{stat.value}</span>
          </div>
        )),
        "grid gap-1 border-t border-line pt-3",
      )}
      {part(
        "open",
        <>
          <span>Open Mulch</span>
          <span>Rescan</span>
          <span className="ml-auto">Quit</span>
        </>,
        "flex gap-3.5 text-muted-foreground",
      )}
    </div>
  )
}
