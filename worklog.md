# Current work

Goal: add a Health-inspired cumulative workout-load comparison to the History
session hero and the completed active-workout summary.

Progress:

- The pure comparison model averages fully comparable archived workouts over
  normalized start-to-finish progress; partial or unavailable load stays hidden.
- The shared chart is inside the History hero and above the completed live
  receipt's exercise list. The existing receipt remains vertically scrollable.
- The History hero omits the density and hard-set intensity line; its footer now
  moves directly from Top set to the load-comparison separator.
- Exact totals, redundant series labels, and one VoiceOver summary preserve the
  meaning in dark, light, and Accessibility XXXL presentations.
- No persistence or snapshot contract changed.

Verification complete: 19 focused model/debug-fixture tests passed,
`Scripts/check.sh` passed, and headless scenarios passed for the live summary in
dark, light, and Accessibility XXXL plus the archive transition and History
detail placement.

Next: observe whether normalized set progress remains the clearest comparison
once real-world workout histories exercise the feature.

User steering: keep the current Vivobody design, place the History chart below
a separator inside the top card, and place the completed live-summary chart
above the exercise list in a vertically scrollable receipt. Remove the
density/hard-set line from the History workout card only.
