import { renderToString } from "react-dom/server"
import { App } from "@/App"

/** Renders the page to HTML at build time; `scripts/prerender.ts` inlines it into index.html. */
export function render() {
  return renderToString(<App />)
}
