# Workout app principles

- Status: Active product principles
- Product decisions confirmed: 2026-09-05 — light and dark appearances; five tabs maximum

These are the shared constraints for product work. Feature behavior is described
in the active contracts linked from [specs/index.md](specs/index.md). The
[early design explorations](specs/product-design-explorations.md) preserve
specific motion, sound, and gesture ideas as history; they are not a feature
backlog or a requirement to change an existing flow.

## Design for training

The user may be sweating, breathing hard, holding a barbell, and glancing at
the screen between sets. Optimize for one-handed use and fast understanding.

- Make the likely next action prominent and thumb-reachable, with at least a
  44pt target.
- Let large, stable numerals lead. Supporting labels must remain readable,
  including at accessibility text sizes.
- Keep workout start and resume easy to find. Detail can be disclosed after
  the immediate action.

## Preserve the workout

Persist meaningful workout changes and restore the active session after an
interruption. Closing or minimizing its presentation does not end the workout.
Surface save failures and preserve a recoverable state. Follow the ownership
boundaries in [ARCHITECTURE.md](ARCHITECTURE.md).

Rest is a core session state: keep the timer visible, understandable, and
actionable, with a clear indication of what comes next.

## Respect the user's effort

Workout logging and history remain free. Do not interrupt an active workout
with purchases or unrelated prompts. Apply the
[Free + Pro contract](specs/free-with-pro-iap.md) at the appropriate surfaces.
Avoid long onboarding wizards, streak-shaming, and prescriptive claims that the
recorded data cannot support.

Use haptic and visual confirmation deliberately; sound is supporting feedback.
Respect user feedback preferences, Reduce Motion, and accessibility semantics.

## Appearance and navigation

Support **both light and dark appearances** across the app. Use the shared
semantic surface, ink, and tint vocabulary so hierarchy and contrast work in
both. Review the changed surface in each appearance; dark mode is not a reason
to omit light-mode verification.

Use **five top-level tabs at most**. The current tabs, in order, are Today,
History, Library, Insights, and Me. Keep new detail within its relevant feature
and apply the five-tab limit when changing navigation.

## Interaction and information

Tap-to-complete sets, drag-to-adjust inputs, and exercise paging are established
workout interactions. Preserve their behavior when making unrelated changes.
Keep accessible actions available and reuse native controls and shared components.

Let the completed summary read as a compact receipt. Present trends as descriptive
information with clear units, timeframe, and data limitations. The muscle map
estimates training attention; it does not measure physiology.

## Product boundaries

Social feeds, coach chatbots, AI form analysis, and XP-style gamification are
outside the current product. Keep the app focused on logging and understanding
training. Research documents and early design ideas do not authorize adding
these features.

The maintainability and evidence requirements live in
[engineering/quality.md](engineering/quality.md) and
[engineering/verification.md](engineering/verification.md).
