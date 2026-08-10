# Catalog-v2 families

This directory contains one reviewed JSON source file per movement family.
`horizontal-press.json`, `incline-press.json`, `decline-press.json`, and
`vertical-press.json` establish the initial small-batch workflow; later
families follow the same contract-first process. Vertical press now uses a
reviewed coverage batch: ten exercises collectively exercise every admitted
equipment, laterality, support, grip, path, kettlebell-orientation, and machine
mechanism value without generating their Cartesian product.

Files here must never be derived from, compared with, or merged with the legacy
exercise roster. `Scripts/catalog_v2.py --check` discovers and validates every
`*.json` file in this directory.

Press families reuse the same mechanical vocabulary. `kineticChain` describes
distal fixation, `scapularTranslation` records only external support limits on
translation rather than rotation or tilt, and signed `pressInclinationDegrees`
uses horizontal as zero. Family-specific synonyms for these axes are not
allowed.

When a variant axis implies extra trunk or segment control, an exercise rule
uses `requireAdditionalStabilityDemands` to require the region explicitly in
`additionalStabilityDemands`. The normal anatomy validation separately proves
that an assigned muscle can stabilize every declared region.
