// Makes dist/index.html paint without waiting on anything but itself:
//  1. inlines the server-rendered page, so the first paint needs no JS;
//  2. inlines the stylesheet (about 10 KB gzipped), removing the render-blocking request;
//  3. preloads the two fonts the hero headline and copy use.
// Runs after `vite build` and `vite build --ssr`; Node runs this file directly (type stripping).
import { readdir, readFile, rm, writeFile } from "node:fs/promises"

const dist = new URL("../dist/", import.meta.url)
const ssrDir = new URL("../dist-ssr/", import.meta.url)
const indexFile = new URL("index.html", dist)
const rootMarker = '<div id="root"></div>'
const heroFonts = [/^instrument-serif-latin-400-normal-.*\.woff2$/, /^inter-tight-latin-wght-normal-.*\.woff2$/]

const { render } = (await import(new URL("entry-server.js", ssrDir).href)) as { render: () => string }
let html = await readFile(indexFile, "utf8")
if (!html.includes(rootMarker)) throw new Error(`prerender: ${rootMarker} not found in dist/index.html`)
html = html.replace(rootMarker, `<div id="root">${render()}</div>`)

const stylesheet = html.match(/<link rel="stylesheet"[^>]*href="\/(assets\/[^"]+\.css)"[^>]*>/)
if (!stylesheet?.[1]) throw new Error("prerender: stylesheet link not found")
const css = await readFile(new URL(stylesheet[1], dist), "utf8")
html = html.replace(stylesheet[0], () => `<style>${css}</style>`)

const assets = await readdir(new URL("assets/", dist))
const preloads = heroFonts
  .map((pattern) => assets.find((name) => pattern.test(name)))
  .filter((name): name is string => Boolean(name))
  .map((name) => `<link rel="preload" href="/assets/${name}" as="font" type="font/woff2" crossorigin>`)
html = html.replace("</head>", `${preloads.join("")}</head>`)

await writeFile(indexFile, html)
await rm(ssrDir, { recursive: true, force: true })
console.log(`prerender: page HTML, ${(css.length / 1024).toFixed(0)} KB CSS and ${preloads.length} font preloads inlined`)
