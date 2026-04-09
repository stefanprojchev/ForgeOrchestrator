/**
 * Forge Ecosystem — shared package registry.
 * Update URLs here when deploying to production (e.g. GitHub Pages).
 */

export interface ForgePackage {
  abbrev: string;
  name: string;
  description: string;
  url: string;
}

export const forgePackages: ForgePackage[] = [
  {
    abbrev: "FI",
    name: "ForgeInject",
    description: "Lightweight dependency injection for iOS. Property wrapper. Thread-safe.",
    url: "https://stefanprojchev.github.io/ForgeInject",
  },
  {
    abbrev: "FO",
    name: "ForgeObservers",
    description: "Reactive system observers. Connectivity, lifecycle, keyboard, and more.",
    url: "https://stefanprojchev.github.io/ForgeObservers",
  },
  {
    abbrev: "FS",
    name: "ForgeStorage",
    description: "Type-safe persistence. Key-value, file storage, and Keychain.",
    url: "https://stefanprojchev.github.io/ForgeStorage",
  },
  {
    abbrev: "FB",
    name: "ForgeBackgroundTasks",
    description: "BGTaskScheduler registration, scheduling, and dispatch for iOS.",
    url: "https://stefanprojchev.github.io/ForgeBackgroundTasks",
  },
  {
    abbrev: "FL",
    name: "ForgeLocation",
    description: "Location-based triggers. Geofencing, significant changes, and visits.",
    url: "https://stefanprojchev.github.io/ForgeLocation",
  },
  {
    abbrev: "FP",
    name: "ForgePush",
    description: "Push notification management. Permissions, tokens, and routing.",
    url: "https://stefanprojchev.github.io/ForgePush",
  },
  {
    abbrev: "FO2",
    name: "ForgeOrchestrator",
    description: "Sequence, pipeline, and monitor orchestrators for iOS app flows.",
    url: "https://stefanprojchev.github.io/ForgeOrchestrator",
  },
];
