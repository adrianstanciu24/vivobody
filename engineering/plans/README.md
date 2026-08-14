# Execution plans

Checked-in plans are for expensive, risky, or multi-session work where losing
context would create rework or product risk. Use them for persistence
migrations, HealthKit or StoreKit changes, widgets, watchOS, large UX changes,
and similarly cross-cutting work. Small changes do not need a plan file.

Active plans live in [active/](active/). Completed plans move to
[completed/](completed/) after their result and evidence are recorded.

A useful plan is executable by another contributor and stays current while
work proceeds. It contains:

- outcome and non-goals;
- relevant source, specs, and decisions;
- risks, invariants, and rollback or recovery strategy;
- ordered milestones with observable completion criteria;
- validation commands plus device/manual checks;
- progress notes and newly discovered facts;
- final result, deviations, and evidence.

Do not copy schema versions, target settings, or other volatile inventories
into a plan unless the exact before/after value is the subject of the change.
Link the source of truth instead.
