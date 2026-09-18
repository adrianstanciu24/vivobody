# Commercial-gym machine first wave — August 2026

Status: four original exact fixtures active; the two held categories now have exact Insignia fixtures active. Other mechanisms remain unreviewed.

## Decisions

| Candidate | Outcome | Canonical owner | Boundary |
|---|---|---|---|
| Life Fitness Pro 2 PSADC assisted dip | Active | `dip` expansion | Full bodyweight minus selected assistance; compare assistance only on PSADC. |
| Life Fitness Pro 2 PSTE seated triceps extension | Active | `elbow-extension` expansion | Supported upper arms, pivot-aligned elbows, and selectorized guided handles. |
| Technogym Selection Glute kickback | Active | `hip-extension` expansion | Unilateral 90-degree-flexion-to-neutral fixture with the knee held near extension. |
| Life Fitness Pro 2 PSPEC pec fly | Active | New `upper-arm-pad-chest-fly` family | Combined forearm/elbow pads plus gripped rotating handles remain separate from handled-only chest-fly history. |
| Machine hip thrust / glute drive | Exact SS-GLB active | `belt-loaded-machine-glute-bridge` | Life Fitness Insignia SS-GLB selectorized belt fixture only; other mechanisms do not share its history. |
| Seated abdominal crunch machine | Exact SS-AB active | `seated-machine-abdominal-crunch` | Life Fitness Insignia SS-AB seated upper-torso crunch only; other abdominal machines remain unreviewed. |

## Evidence and product gate

The active Life Fitness records use the manufacturer's April 2007 Pro 2
owner's manual for exact fixture identity, contacts, assistance direction, and
execution. The Technogym record uses Stien et al. 2021 (DOI
`10.52082/jssm.2021.56`) for the Selection kickback study setup, joint range,
and measured gluteus-maximus and biceps-femoris-site participation, then the
undated Selection Glute manufacturer manual for the matching product's pad,
platform, roller, handgrip, and selectorized cable-lever topology. The manual's
registry year is transparently the 2026 retrieval year, not a claimed
publication date. Existing joint-function sources bound categorical roles
where the fixture sources do not rank muscles.

Every external machine record uses
`enteredExternalLoadSameFixtureOnly`. The assisted dip instead uses
`assistanceSubtracted`, a full-bodyweight fraction, and explicit copy that more
selected assistance makes the repetition easier. Generic aliases remain
searchable, but stable catalog IDs keep incompatible machine mechanisms out of
the same workout history.

## Original holds and September resolution

The original evidence gaps below describe the unidentified machine conditions,
not a blanket requirement for measured kinematics or exact EMG. On 2026-09-18,
the owner authorized the three [common machine additions](common-machine-additions-2026-09.md).
The existing 2024 Insignia manufacturer manual and start/finish diagrams resolve
exact SS-AB and SS-GLB fixture geometry; existing anatomical capabilities support
explicitly bounded categorical action and role inferences. They do not activate
the unidentified research machines or every fixture using the same search alias.

- **Machine hip thrust:** identify the exact tested or owner-selected model and
  obtain an authoritative manual that fixes the body contacts, lever/load
  interface, start and endpoint, and resistance mechanism. The nearest study is
  Petrizzo, Lopez, Gaeta, Aquino, Otto, and Wygand (2023), “Machine Vs. Barbell
  Hip Thrust: Electromyographic, Biomechanical, And ‘Ease Of Use’ Comparison,”
  DOI [`10.1249/01.mss.0000986876.72568.fb`](https://doi.org/10.1249/01.mss.0000986876.72568.fb).
  It compares a machine condition but does not identify the tested model or
  resistance topology.
- **Seated abdominal crunch:** obtain direct kinematics or an authoritative
  exact-model manual that resolves hip and pelvic motion. EMG alone cannot
  decide whether the fixture belongs in strict `spine-flexion` or a compound
  trunk-and-hip family. Sundstrup, Jakobsen, Andersen, Jay, and Andersen (2012),
  “Swiss Ball Abdominal Crunch With Added Elastic Resistance Is an Effective
  Alternative to Training Machines,” PMID `22893857`, PMCID
  [`PMC3414069`](https://pmc.ncbi.nlm.nih.gov/articles/PMC3414069/), identifies
  a Technogym seated crunch and measures abdominal, oblique, and rectus-femoris
  EMG but does not report the hip or pelvic kinematics needed for ownership.

The exact SS-AB and SS-GLB records are now emitted into the runtime catalog and
have conventional search aliases. The unidentified research fixtures remain
excluded; aliases do not establish load equivalence between mechanisms.

Original source verification date: **2026-08-29**. Insignia follow-up: **2026-09-18**.
