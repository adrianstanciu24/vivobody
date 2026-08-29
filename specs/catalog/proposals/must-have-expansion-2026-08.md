# Must-have catalog follow-up — August 2026

Status: active as four source-bounded records.

## Decisions

| Requested exercise | Outcome | Canonical owner |
|---|---|---|
| Barbell Clean & Jerk | New ordered-phase family | `clean-and-jerk` |
| Paired-Dumbbell Forward Lunge | Narrow family expansion | `dynamic-lunge` |
| Standing EZ-Bar Curl | Narrow family expansion | `elbow-flexion` |
| Bilateral Barbell Lying Triceps Extension | Narrow family expansion | `elbow-extension` |

The combined clean and jerk owns one load and one history because the IWF
defines it as one competition lift, while the clean and split-jerk studies
bound its component phases. It does not merge the separately trackable clean
or jerk records.

The loaded forward lunge preserves Riemann et al.'s step-and-return topology,
70%-leg-length step, maximum comfortable depth, and paired side-held load. The
study used purpose-built dumbbell-like tracking implements, so the product's
dumbbell mapping is explicit and the logged load is per implement.

The EZ-bar curl preserves the study's standing simultaneous undulated-bar
fixture and near-semipronated forearm position. Grip width, wrist posture, and
upper-arm angle remain unreported.

The lying barbell triceps record preserves Brandao et al.'s 90-degree shoulder
position and elbow excursion from 90 degrees of flexion to full extension.
Bar shape, grip width, forearm orientation, wrist posture, support surface, and
face-relative path remain unreported; `Skull Crusher` is therefore not an
alias.

## Evidence gate

- IWF Technical and Competition Rules, 2025 edition: combined clean-and-jerk
  competition topology.
- Riemann et al. 2012, DOI `10.4085/1062-6050-47.4.16`: externally loaded
  anterior-lunge fixture.
- Marcolin et al. 2018, PMID `30013836`: standing EZ-bar curl fixture.
- Brandao et al. 2020, PMID `32149887`: bilateral lying barbell triceps-press
  fixture.

All four passed duplicate, family-contract, generated-catalog, mutation, and
runtime projection gates. The active projection is 83 families and 200
exercises with 222 registered evidence sources.
