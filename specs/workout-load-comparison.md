# Workout load comparison

- Status: Implemented
- Product surfaces: History session detail and completed active-workout summary

## User job

Show how one workout's accumulated comparable volume differs from the user's
typical completed workout without introducing a score or pretending that set
timestamps exist.

## Contract

- The orange line is this workout; the gray line is the average of fully
  comparable archived workouts.
- Both lines use one canonical-volume scale and accumulate ordered completed
  sets from normalized workout start to finish. Normalized progress is used
  because sets do not persist completion timestamps and workouts vary in
  length.
- The exact current and average totals remain visible above the chart. Color is
  redundant with labels and VoiceOver names both values, the archive sample,
  and the start-to-finish scope.
- The chart is omitted when the current workout has partial or unavailable
  comparable load, or before a comparable archived baseline exists.
- History places the instrument below a separator inside the session hero.
  Its footer moves from Top set directly to the comparison separator; the
  density/hard-set intensity line is omitted from this History card only.
  The completed live receipt places it above the exercise list and remains
  vertically scrollable.

## Product observation

Normalized set progress is the current comparison contract. Its usefulness on
real workout histories remains a product observation, not an active task or an
instruction to change the chart.
