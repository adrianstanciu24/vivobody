# Paid-upfront app

Status: Active product contract. Confirmed 2026-09-07.

Vivobody has an upfront App Store price. All existing app features are included;
there are no in-app purchases, subscriptions, restore-purchase flows, or Pro tiers.
The exact app price is selected separately in App Store Connect.

- Insights renders its real interactive reports without purchase blur or banners.
- Exercise Detail includes progress, weekly volume, load cadence, stamina, and
  comparison whenever their existing data and context requirements are met.
- Templates have no purchase-related count limit, including routine-builder saves.
  The routine builder remains intentionally hidden behind its existing DEBUG route.
- Signature, Consistency, and Strength widgets render their snapshots directly.
- Apple Health remains opt-in and requires device availability and authorization.
- Settings has no upgrade or purchase-status section.

Missing history still produces the existing empty/building states. Comparison
and stamina keep their existing active-workout context restrictions. No analytics
formula, workout persistence schema, or widget snapshot payload changes.

The app no longer reads or mirrors purchase preferences. Older `vivobody://pro`
widget links open Insights. StoreKit remains only for the system app-review API.

The [former Free + Pro design](free-with-pro-iap.md) is historical and superseded.
