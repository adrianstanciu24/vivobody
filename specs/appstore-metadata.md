# App Store Connect metadata — Vivobody 1.0

Status: Release artifact; recheck copy, platform requirements, and submission
values before use. Source-audit date: [spec index](index.md).

Everything below is paste-ready for App Store Connect. Fields that ASC
limits by character count are annotated; all drafts fit their limits.

## App record

| Field | Value |
|---|---|
| Name (30 chars max) | Vivobody |
| Subtitle (30 chars max) | Focused workout tracking |
| Bundle ID | astanciu.vivobody.app |
| SKU | vivobody-ios |
| Primary language | English (U.S.) |
| Primary category | Health & Fitness |
| Secondary category | (none, or Lifestyle) |
| Price | Free (Pro is a $24.99 in-app purchase) |
| Privacy policy URL | https://vivobody.app/privacy/ |
| Support URL | https://vivobody.app/support/ |
| Marketing URL (optional) | https://vivobody.app/ |
| Copyright | 2026 Adrian Stanciu |

The Settings screen intentionally omits a Rate Vivobody row until the
App Store record has a public numeric Apple ID. Add the review link in a
later app update once the product page is live; do not ship a placeholder
App Store URL.

## Promotional text (170 chars max)

> Log sets in seconds, watch your training load in real time, and see
> every muscle you've built light up on a 3D body. All on-device.

## Description (4000 chars max)

> Vivobody is a workout tracker built for the moment between sets:
> huge readable numbers, one-thumb logging, and a rest timer that is
> always exactly where you need it.
>
> Everything lives on your iPhone. No account, no cloud, no ads, no
> tracking. Your training data belongs to you.
>
> LOG WITHOUT FRICTION
> - Start from a template or an empty session and swipe between exercises
> - Scrub weights and reps with a drag instead of typing
> - Every interaction is saved instantly, so you never lose a set
> - Rest timer with Live Activity and Dynamic Island support
> - Plate visualizer shows exactly what to load on the bar
>
> SEE WHAT YOU'RE BUILDING
> - A rotatable 3D body highlights the muscles each workout hits
> - Weekly volume per muscle group, tracked against your own baseline
> - Personal records celebrated the moment they happen
>
> UNDERSTAND YOUR TRAINING (PRO)
> - Training load and readiness based on your acute and chronic workload
> - Strength outlook and rep-range trends per exercise
> - Consistency, intensity mix, and symmetry reports
> - Unlimited workout templates
> - Save finished workouts to Apple Health (write-only, never reads)
> - Home Screen and Lock Screen widgets
>
> BUILT INTO iOS
> - Siri Shortcuts and Spotlight search for your templates
> - Start a workout from Control Center
> - Widgets for your next workout and weekly consistency
>
> Vivobody Pro is a single lifetime purchase. No subscription.

## Keywords (100 chars max)

> workout,gym,lifting,strength,tracker,log,sets,reps,muscle,rest timer,bodybuilding,fitness

(97 chars including commas.)

## What's New (first release)

> Initial release.

## Age rating questionnaire

Answer "None" to every content category (violence, sexual content,
profanity, drugs, gambling, horror, etc.). Unrestricted web access: No.
Gambling and contests: No. Result should be 4+.

## App privacy (nutrition label)

- Does this app collect data? **No — "Data Not Collected."**
- This matches the shipped `PrivacyInfo.xcprivacy` (no tracking, no
  collected data types). Health data is written to Apple Health only at
  the user's request and never leaves the device, which does not count
  as collection by the developer.

## In-app purchase

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Product ID | astanciu.vivobody.app.pro.lifetime |
| Reference name | Vivobody Pro Lifetime |
| Price | $24.99 (Tier: pick closest to 24.99 USD) |
| Family Sharing | Off (matches Products.storekit) |
| Display name (30 chars max) | Vivobody Pro |
| Description (45 chars max) | Insights, unlimited templates, Health sync. |

IAP review screenshot: any screenshot of the paywall sheet (run the app
with `--seed-showcase`, open Settings > Unlock Vivobody Pro, capture at
6.9"). Attach the IAP to the 1.0 version submission so both are
reviewed together.

## App Review notes (paste into "Notes" for the reviewer)

> Vivobody is fully on-device: no account or sign-in exists, so no demo
> credentials are needed.
>
> HealthKit: the app requests WRITE-ONLY authorization, and only when
> the user enables "Apple Health" in Settings (part of the Pro
> purchase). It saves finished workouts as HKWorkout samples. It never
> reads Health data.
>
> In-app purchase: Vivobody Pro (non-consumable lifetime unlock). To
> reach the paywall: Settings (gear icon on the Me tab) > "Unlock
> Vivobody Pro", or create a 6th workout template in Library >
> Templates. "Restore Purchases" is on the paywall sheet.
>
> Live Activity: starting a workout shows a Live Activity with the
> rest timer in the Dynamic Island.

## Submission checklist (ASC side, in order)

1. Agreements, Tax, and Banking: sign the Paid Applications agreement,
   complete banking + tax forms (required before the IAP can be sold).
2. Certificates/profiles: handled by Xcode automatic signing at upload.
3. Create the app record (bundle ID astanciu.vivobody.app must already
   exist in the Developer portal; Xcode's automatic signing created it).
4. Create the in-app purchase (table above) + its review screenshot.
5. Fill App Information, Pricing (Free), App Privacy (Data Not
   Collected), Age Rating.
6. Verify `https://vivobody.app/`, `/privacy/`, and `/support/` all
   resolve before submitting.
7. Upload the build: Xcode > Product > Archive > Distribute App >
   App Store Connect (or `xcodebuild -exportArchive`).
8. Add screenshots (6.9" required; candidates in .verify/ or shoot via
   `SIMULATOR_NAME='iPhone 17 Pro Max' LAUNCH_ARGS='--seed-showcase --pro' Scripts/verify.sh`).
9. Attach the IAP to the version, paste description/keywords/promo
   text, paste the review notes, submit.
10. Recommended: TestFlight the build on your own device first.
