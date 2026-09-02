# Current work

Goal: close the active-exercise-card refactor review findings without changing
the visible instrument or weakening the controller-owned transaction.

Progress:

- Fixed the post-commit scrub race by cancelling card scrubbing again while the
  coordinator gate is still closed, before the next set can accept input.
- Restored external/widget foregrounding when no pending set exists and restored
  `completedAt` after a failed archive so the retained draft remains loggable.
- Kept the set mutation inside the completion spring while moving PR
  presentation state outside it; removed the dead scrub-save parameter.
- Added focused coverage for coordinator cleanup, nil-set external completion,
  failed archive retry eligibility, and PR transaction timing. All 10 focused
  tests pass on a clean ephemeral simulator.
- `start-complete-rest` and `active-completion-restoration` pass in headless
  Baguette; their settled screenshots and accessibility trees were inspected.
- Kept the more direct all-complete summary route and documented it as a
  deliberate parity deviation in the completed execution plan.
- The post-fix canonical `Scripts/check.sh`, formatting, diff check, and final
  review pass.

Next:

- Verify the exact acknowledgement-window flywheel gesture, haptic/audio timing,
  one-handed reach, and real VoiceOver rotor order on a physical device.

User steering: fix the six reported completion-refactor findings; retain the
new all-complete summary route and record it as a deliberate plan deviation.
