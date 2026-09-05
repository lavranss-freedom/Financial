# Personal Overview (iOS)

Native SwiftUI iOS app mirroring the Personal Overview PWA — net worth (Stance), listed book + crypto, candidates boards, alerts, and settings, gated by a local PIN.

## Open & run on a Mac

1. Clone this repo (or pull `main`).
2. Open **`PersonalOverview.xcodeproj`** in Xcode 15+ (iOS 17 SDK).
3. Select an **iPhone simulator** (or a physical device).
4. Press **Run** (▶).

First launch asks you to set a **4–6 digit PIN** (stored in Keychain). After unlock, the app loads bundled **`SeedData.json`** (2026-09-04 book snapshot). Relock from **Settings → Lock now**.

### Signing / distribution

- **Simulator**: no paid Apple Developer account required.
- **Device sideload** with a free Apple ID works with Xcode’s automatic signing (7-day cert limits, app count limits).
- **TestFlight / App Store** requires an Apple Developer Program membership (~US$99/year).

Set your team under the **PersonalOverview** target → *Signing & Capabilities* if deploying to a device.

## What’s included

| Tab | Behavior |
|-----|----------|
| **Stance** | Net worth NOK: house equity % − mortgage half + listed + crypto(USD→NOK) + cash + other assets − other debts. Leased car off-balance. Editable houses/mortgage/cash; other assets list (seed Ducati Streetfighter 848 @ 0 NOK). |
| **Book** | Holdings table (qty, GAV, last, day%, AH%, value NOK, return, weight, sleeve). Detail + Analyze brief. Mandate: 20%+ goal, whole shares, no leverage, moonshots ≤3%. Fisker IGNORE/0. Delayed Yahoo quotes with last/GAV offline fallback. |
| **Candidates** | Core/Fortress/Growth board + Moonshots board. Promote / Reject / Watch stubs (logged). |
| **Alerts** | Seeded welcome alert + action log; move alerts placeholder. |
| **Settings** | USDNOK edit, holdings edit stub note, JSON backup export, lock / logout+clear PIN. |

**Bundle ID:** `com.lavranss.PersonalOverview`  
**Display name:** Personal Overview  
**Deployment:** iOS 17+

## Project layout

```
PersonalOverview.xcodeproj
PersonalOverview/
  PersonalOverviewApp.swift    # SwiftUI @main + WindowGroup
  ContentView.swift            # PIN gate → tabs
  Models/                      # Codable book models + AppDataStore
  Views/                       # Stance, Book, Candidates, Alerts, Settings, PIN
  Services/                    # Keychain, Yahoo quotes, calc, analyze, seed loader
  Theme/                       # Dark navy + gold
  Resources/SeedData.json      # Bundled 2026-09-04 seed
  Assets.xcassets
  Info.plist
```

## Quotes

The app calls Yahoo Finance chart API directly via `URLSession` (`query1.finance.yahoo.com/.../chart/{symbol}`). Quotes are **delayed**; the UI labels them as such. If a fetch fails, marks stay at last/GAV from seed or prior refresh.

## PWA

The web PWA remains live at [https://personal-overview-be9.pages.dev](https://personal-overview-be9.pages.dev) until the native app ships for daily use.

## Scaffold note

Cloud Agents / Mac pool were unavailable on the current Cursor plan, so this Xcode project was scaffolded on Linux. Open it on a Mac with Xcode to build and run — the simulator was not executed in CI here.

## License / privacy

Personal portfolio data is local-first (Keychain PIN + UserDefaults persistence + optional JSON export). No accounts, no backend required for the seed path.
