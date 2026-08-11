# Catalog-v2 families

This directory contains one reviewed JSON source file per movement family.
`horizontal-press.json`, `incline-press.json`, `decline-press.json`,
`vertical-press.json`, `vertical-pull.json`, and
`shoulder-extension-row.json` are the currently reviewed real families. Each
uses a coverage batch whose exercises collectively exercise every admitted
axis value without generating the Cartesian product. Shoulder-extension row
uses 12 reviewed exercises to cover five equipment classes, open and closed
chains, supported and unsupported torsos, unilateral control, free and fixed
external paths, and its pinned bodyweight setup.

Files here must never be derived from, compared with, or merged with the legacy
exercise roster. `Scripts/catalog_v2.py --check` discovers and validates every
`*.json` file in this directory.

Press families reuse the same mechanical vocabulary. `kineticChain` describes
distal fixation, `scapularTranslation` records only external support limits on
translation rather than rotation or tilt, and signed `pressInclinationDegrees`
uses horizontal as zero. Family-specific synonyms for these axes are not
allowed.

`lowerBodySupport` has one cross-family meaning: the lower-body contact or
support that materially changes effective bodyweight loading. A family that
declares this axis makes it required and includes an explicit `none` value when
no such contact participates. Family-specific non-`none` values describe the
actual mechanism: horizontal press uses `feet|knees`, vertical pull uses
`thighPad|assistancePlatform`, and shoulder-extension row uses `feet` only for
its pinned bodyweight branch.

When a variant axis implies extra trunk or segment control, an exercise rule
uses `requireAdditionalStabilityDemands` to require the region explicitly in
`additionalStabilityDemands`. The normal anatomy validation separately proves
that an assigned muscle can stabilize every declared region. When the setup
requires one member of a biomechanically valid muscle set rather than one exact
assignment, `requireMuscleRequirements` reuses the family muscle-requirement
shape (`anyOf` plus `minimumRole`) without forcing an arbitrary muscle.

`relativeGripWidth` has the shared ordered vocabulary
`narrow|shoulderWidth|medium|wide`. Families may select a reviewed subset, but
the same value cannot change meaning between families.

Family planes are determined only by the declared shoulder basis actions.
Shoulder-extension row is therefore sagittal because its basis action is
`shoulder.extension`; its transverse `scapula.retraction` prime action occurs
at a different joint and must not be used to add a false transverse shoulder
plane.
