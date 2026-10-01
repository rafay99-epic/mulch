import { useEffect, useState } from "react"

/** Copies text to the clipboard and reports `copied` for two seconds. */
export function useCopy() {
  const [copied, setCopied] = useState(false)
  useEffect(() => {
    if (!copied) return
    const timer = setTimeout(() => setCopied(false), 2000)
    return () => clearTimeout(timer)
  }, [copied])
  const copy = async (text: string) => {
    await navigator.clipboard.writeText(text)
    setCopied(true)
  }
  return { copied, copy }
}
