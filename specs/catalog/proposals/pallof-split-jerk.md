# Pallof Split Jerk — blocked fixture proposal

- Status: Blocked by unresolved combined-fixture contract
- Reviewed: 2026-09-21

## Requested fixture

The requested name uniquely matches Boxing Science's **Pallof Split-Jerk**: start square to a side-anchored band with both hands near the sternum, rapidly hop into an asymmetric split stance while pressing the hands forward, then return to the square stance while retracting the hands.

This is not a stationary split-stance Pallof press and is not the barbell split jerk. It cannot enter the active `anti-rotation-press` family because that contract fixes a hip-width parallel stance, static lower-body support, cable resistance, and no flight or receiving phase.

## Evidence boundary

- Boxing Science's [Pallof press progression](https://boxingscience.co.uk/rotational-strength-and-power-for-boxing-the-pallof-press/) supplies the unique name and demonstration, but does not fully prescribe lead-leg alternation, foot spacing, receiving depth, repetition counting, or joint-action semantics.
- Juan-Recio et al., [*Effect of Body Position and Support Surface on the Postural Control Challenge During the Pallof Press Exercise*](https://doi.org/10.3390/medicina61020312), supports band anti-rotation demand but studies static holds, not the hop-and-receive fixture.
- ACE's [Standing Anti-Rotation Press](https://www.acefitness.org/resources/everyone/exercise-library/332/standing-anti-rotation-press/) supports the arm press and return, not the split transition.

The combined movement needs an explicit product decision about whether lower-body flight and split receipt are training-defining power phases or uncredited support transitions. Activating it without that decision would either omit material hip, knee, and ankle work or invent unsupported ordered actions.

## Candidate contract after unlock

- New family: `band-pallof-split-jerk`
- Candidate record: `band-pallof-split-jerk`
- Band resistance, non-comparable load, repetitions, both anchor sides
- Core training role with resisted `spine.rotation`
- Exclude stationary split-stance presses, cable presses, overhead jerks, stepping-only variants, and perturbation holds

## Concrete unlock

Confirm the Boxing Science demonstration as the intended fixture and decide whether the catalog should credit the hop and split receive as lower-body power phases. Also specify whether lead legs alternate within a set or use separate sets.
