import { MotionProvider } from "@/components/motion/MotionProvider"
import { Hero } from "@/sections/Hero"
import { HowToUse } from "@/sections/HowToUse"
import { Install } from "@/sections/Install"
import { Lanes } from "@/sections/Lanes"
import { Ledger } from "@/sections/Ledger"
import { SiteFooter } from "@/sections/SiteFooter"
import { SiteNav } from "@/sections/SiteNav"
import { Stats } from "@/sections/Stats"
import { Steps } from "@/sections/Steps"

/** Page order is the story: what it is, what it clears, how it works, how to use it, why it is safe, install. */
export function App() {
  return (
    <MotionProvider>
      <SiteNav />
      <main>
        <Hero />
        <Ledger />
        <Steps />
        <HowToUse />
        <Lanes />
        <Stats />
        <Install />
      </main>
      <SiteFooter />
    </MotionProvider>
  )
}
