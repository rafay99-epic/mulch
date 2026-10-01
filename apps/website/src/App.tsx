import { MotionProvider } from "@/components/motion/MotionProvider"
import { Features } from "@/components/sections/Features"
import { Footer } from "@/components/sections/Footer"
import { Hero } from "@/components/sections/Hero"
import { Install } from "@/components/sections/Install"

/** Page composition. Each section owns its own markup; add or reorder them here. */
export function App() {
  return (
    <MotionProvider>
      <main>
        <Hero />
        <Features />
        <Install />
      </main>
      <Footer />
    </MotionProvider>
  )
}
