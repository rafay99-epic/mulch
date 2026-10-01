/** Site copy and links in one place, so sections stay presentational. */
export const site = {
  name: "Mulch",
  tagline: "Clears dev junk off your Mac every week.",
  repo: "https://github.com/rafay99-epic/mulch",
  features: [
    { title: "Weekly, in the background", body: "Runs when your Mac is idle and on power." },
    { title: "Asks before anything risky", body: "Docker images, SDKs and old versions wait for approval." },
    { title: "Never touches your work", body: "Worktrees, emulators and simulators are off limits." },
  ],
  install: [
    "gh repo clone rafay99-epic/mulch ~/Code/mulch",
    "cd ~/Code/mulch/apps/desktop",
    "./Scripts/make-signing-cert.sh",
    "./Scripts/install.sh",
  ],
} as const

export type Feature = (typeof site.features)[number]
