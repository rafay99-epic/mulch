import { m, type MotionValue, useMotionValue, useTransform } from "motion/react"
import type { ReactNode } from "react"
import type { InspectorData, SizeRow } from "@/content/types"
import { cn } from "@/lib/utils"

interface InspectorWindowProps {
  data: InspectorData
  /** 0..1. Lifts the three panes off the window in 3D, each to its own depth. */
  depth?: MotionValue<number>
}

/** The Mulch main window: rules, the selected rule's items, and the inspector. */
export function InspectorWindow({ data, depth }: InspectorWindowProps) {
  const flat = useMotionValue(0)
  const d = depth ?? flat
  return (
    <div className="flex h-[520px] w-[1000px] flex-col rounded-[14px] border border-[#3a3a3c] bg-panel text-[13px] transform-3d">
      <div className="flex h-11 flex-none items-center gap-2 border-b border-line px-4">
        {[0, 1, 2].map((i) => (
          <i key={i} className="size-3 rounded-full bg-[#3a3a3c]" />
        ))}
        <span className="ml-3 font-semibold text-muted-foreground">Mulch</span>
        <span className="ml-auto flex items-center gap-2.5 text-muted-foreground">
          {data.reclaimable} reclaimable
          <b className="rounded-full bg-leaf px-3 py-1 text-black">Clean</b>
        </span>
      </div>
      <div className="grid min-h-0 flex-1 grid-cols-[1fr_1.2fr_1fr] transform-3d">
        <Layer depth={d} z={50} className="rounded-bl-[14px] bg-[#111]">
          <Label>Weekly</Label>
          {data.weekly.map((row) => (
            <Row key={row.name} row={row} selected={row.selected} />
          ))}
          <Label>Asks first</Label>
          {data.asks.map((row) => (
            <Row key={row.name} row={row} nameClass="text-ask" />
          ))}
        </Layer>
        <Layer depth={d} z={100} className="bg-panel">
          <div className="mb-1.5 flex flex-col border-b border-line px-2 pb-2.5 pt-1">
            <b>{data.rule.title}</b>
            <span className="text-muted-foreground">{data.rule.summary}</span>
          </div>
          {data.items.map((row) => (
            <Row key={row.name} row={row} selected={row.selected} nameClass="font-mono text-xs" />
          ))}
        </Layer>
        <Layer depth={d} z={150} className="rounded-br-[14px] border-r-0 bg-panel">
          <b className="text-xl">{data.detail.name}</b>
          <code className="mb-3 mt-1 block font-mono text-[11px] text-muted-foreground">{data.detail.path}</code>
          <dl className="mb-4 grid grid-cols-[76px_1fr] gap-x-2.5 gap-y-1.5">
            {data.detail.fields.map((field) => (
              <div key={field.label} className="contents">
                <dt className="text-muted-foreground">{field.label}</dt>
                <dd className={cn(field.accent && "text-leaf")}>{field.value}</dd>
              </div>
            ))}
          </dl>
          <div className="flex gap-2">
            <span className="rounded-full bg-leaf px-3.5 py-1 font-semibold text-black">Clean</span>
            <span className="rounded-full border border-frame px-3 py-1">Reveal in Finder</span>
          </div>
        </Layer>
      </div>
    </div>
  )
}

function Layer({ depth, z, className, children }: { depth: MotionValue<number>; z: number; className?: string; children: ReactNode }) {
  const translateZ = useTransform(depth, (v) => v * z)
  return (
    <m.div style={{ z: translateZ }} className={cn("border-r border-line px-3.5 py-3", className)}>
      {children}
    </m.div>
  )
}

function Row({ row, selected, nameClass }: { row: SizeRow; selected?: boolean; nameClass?: string }) {
  return (
    <div className={cn("flex justify-between rounded-md px-2 py-1.5", selected && "bg-sel")}>
      <span className={nameClass}>{row.name}</span>
      <span className="text-muted-foreground tabular-nums">{row.size}</span>
    </div>
  )
}

function Label({ children }: { children: ReactNode }) {
  return <small className="mb-1 mt-1.5 block text-[11px] text-neutral-500">{children}</small>
}
