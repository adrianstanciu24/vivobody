# Current work

Goal: extract one shared workout-receipt metric contract while preserving the
established live, Today, and History presentation of every metric branch.

Progress:

- Added `WorkoutReceiptMetric` as the shared selection, availability, unit,
  label, and spoken-value contract for live, Today, and History receipts.
- Preserved full grouped volume in the live hero, compact card values elsewhere,
  Today's short partial-volume legend, and the existing `0s` fallback.
- Added singular VoiceOver semantics for one rep, one pound, and one kilogram.
- The focused eight-test suite, dark, light, Accessibility Dynamic Type, and
  cross-screen parity scenarios, structural ratchets, and `Scripts/check.sh` pass.

Next: none; ready for review.

User steering: fix all review findings—preserve receipt behavior, correct
singular accessibility wording, and keep this worklog current.
