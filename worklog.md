# Current work

Goal: close the pre-commit sound audit findings while preserving the selected
sound routing and making only the requested DONE-level adjustment.

Progress:

- Recorded sound routing remains unchanged: click, workout start, set/finish,
  personal record, visible rest expiry, DONE, and destructive alert retain
  their existing actions and haptics.
- Removed the unused atom CAFs (`tick`, `tick-deep`, `thunk`, `rigid`, `soft`,
  `selection`, and `slam`) plus the DEBUG-only `warning` and `failure` CAFs,
  including their generator and runtime references.
- Cleaned all seven WAV masters: removed delayed terminal bursts, shortened
  inaudible padding, faded every ending to exact digital silence, removed the
  timer-expired pre-roll, and reduced only near-full-scale recordings to about
  -2 dBFS peak headroom.
- Removed the generated summary-entrance success sound while retaining its
  one-time success haptic. Minimized-rest and background-notification sounds
  remain unchanged.
- Replaced only the Active Workout DONE finale master with the supplied short
  task-complete recording. Removed its inaudible padding and terminal artifact,
  faded the tail to exact digital silence, then raised the cleaned 80%-level
  master by 15%. It is now 92% of the supplied source level; the routing and
  rising haptic are unchanged.
- The supplied RIR click cleans to the existing `sfx-click.wav` byte-for-byte,
  so every 0…5+ RIR choice now reuses that recording while preserving the
  heavier haptic at 0; the six generated RIR tones and generator paths are gone.
- Corrected the generator's no-op fade, regenerated the intentional CAFs,
  and verified their signal now fades into exact digital silence without
  clipping. Removing the summary sound leaves 16 generated runtime CAFs.
- Confirmed set completion and PR audio are already separated by the 550 ms
  completion delay, so no overlap fix was required. Both Library workout-start
  paths now use the recorded commit sound used by Today.
- The sound resource test now covers and decodes all 23 runtime files, including
  the 12 scrub variants and background rest notification. Settings copy no
  longer describes every sound as a synth blip.
- Audio invariants plus architecture, naming, source-size, complexity,
  formatting, generator inventory, and diff checks pass without a simulator
  run. The documentation check is blocked only by the unrelated user-owned
  deletion of `WIDGET_IMPLEMENTATION_NOTES.md`.

Next:

- User-owned device listen at high volume for clean endings, retained character,
  relative loudness, sound settings, silent-switch behavior, and music mixing.

User steering: use
`/Users/astanciu/Downloads/UIAlert-Short_“task_complete-Elevenlabs.wav` only for
the completed-workout DONE action. Leave RIR feedback unchanged. Increase the
cleaned DONE master by 15% while preserving its silent tail. Skip simulator
runs; the user will test audio.
Remove the nine generated CAF files identified as unused or DEBUG-only.
Use `/Users/astanciu/Downloads/UIAlert-Timer_expired,_syste-Elevenlabs.wav`
when the visible Active Workout timer reaches 0:00.
Clean all recorded WAV endings, then stop for user testing; do not run the
simulator.
Use `/Users/astanciu/Downloads/UIClick-A_short_150ms_satisf-Elevenlabs.wav`
for every RIR choice shown in Active Workout.
Remove the generated success sound from the final-set-to-summary transition;
retain the one-time success haptic.
