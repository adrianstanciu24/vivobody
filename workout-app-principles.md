# Workout app, from first principles

- [ ] The user is the constraint, not the feature list.
- [ ] They're sweating, breathing hard, possibly holding a barbell, looking at the screen from arm's length for 0.5 seconds between sets.
- [ ] Every design decision flows from that reality.

## The five non-negotiables

### 1. One-handed, thumb-reachable, glanceable from 3 feet
- [ ] Numerals are huge, monospaced, weight-bearing.
- [ ] Labels are tiny.
- [ ] The most likely next action is always the biggest target on screen.

### 2. Never lose state
- [ ] If the app crashes mid-set, the user opens it and is exactly where they left off — set count, weight, timer mid-tick.
- [ ] This is sacred.
- [ ] Persist on every interaction, not on app lifecycle events.

### 3. Rest is the product
- [ ] Most of a workout is rest.
- [ ] The rest timer screen is the home screen, not a modal.
- [ ] It should be beautiful, calm, and tell you what's next without you asking.

### 4. Haptic > visual > audio
- [ ] In that priority for confirmation.
- [ ] The user shouldn't have to look to know they tapped the right thing.

### 5. Working out is hard. The app must never be.
- [ ] No onboarding wizard.
- [ ] No "premium" interruptions.
- [ ] No streak-shaming.
- [ ] Respect the user's effort.

## Interaction model

- [ ] Tap to complete a set. That's the primary verb. Not "log," not a form — one big tap, with a satisfying haptic thunk.
- [ ] Drag to adjust. Vertical drag on the weight number scrubs it like an iOS picker, with rubber-band physics and a subtle tick haptic on each increment.
- [ ] Same drag-to-adjust behavior for reps.
- [ ] No keyboards mid-workout.
- [ ] Long-press for the secondary action (swap exercise, add a drop set, edit the last entry).
- [ ] Pull-down to skip rest.
- [ ] Pull-up to extend rest 30s.
- [ ] These are gestural, not buttons.
- [ ] Swipe between exercises in the workout — like Stories, but with momentum and a peek of the next one.

## Motion design

- [ ] Spring physics, everywhere. Stiffness ~300, damping ~28.
- [ ] Never `ease-in-out` for anything the user interacts with. Linear easing is the smell of a bad workout app.
- [ ] Numbers tick, they don't fade. When weight changes from 135 to 140, individual digits roll like a mechanical odometer.
- [ ] Shared element transitions between the exercise list row and the active exercise screen. The card you tapped grows into the screen.
- [ ] The rest timer breathes. A subtle radial pulse synced to ~12 BPM — slower than resting heart rate, which actually calms people down.
- [ ] At T-10s on the rest timer, the pulse accelerates and the color warms.
- [ ] Set completion is a moment. A small particle burst, a haptic crescendo (light → medium → success notification), the number locks in with a spring overshoot.
- [ ] Not a confetti vomit. Earned, restrained, repeatable a hundred times without getting old.

## Sound design

- [ ] This is where 99% of fitness apps fail. They use synth beeps that sound like a microwave.
- [ ] Sample real things.
- [ ] A wood block for set complete.
- [ ] A bell for rest end (think singing bowl, not boxing bell).
- [ ] A starter pistol shape for the 3-2-1 countdown — not three identical beeps.
- [ ] Tonal logic. Increment goes up a semitone, decrement goes down.
- [ ] PR sound is in a major key.
- [ ] Failure is a soft, non-judgmental low tone — never a buzzer.
- [ ] Sound always co-occurs with haptic.
- [ ] Sound without haptic feels cheap. Haptic without sound feels premium. Both together feels like a Rolex.
- [ ] Mix-aware. Duck the user's music by 30%, don't pause it.
- [ ] Use the iOS short-form sound category so timers ring over music without stopping it.

## The taste layer

- [ ] Dark mode first. Gyms are dim. Phones are bright. White backgrounds at 6am are violence.
- [ ] One accent color for "in progress," one for "complete." That's it. The rest is grayscale and typography.
- [ ] Type does the work. A great workout app has maybe 5 font sizes and looks like Swiss design, not a dashboard.
- [ ] Reference: Things 3, Tot, Apple's Breathe, Streaks, the Arc browser.
- [ ] No iconography for primary actions. A button that says "REST" beats a button with a clock icon.
- [ ] Icons are for navigation, not verbs.
- [ ] Numerals are first-class citizens. Use a font with proper tabular figures (SF Pro, Inter, JetBrains Mono).
- [ ] 135 lb should never jitter when it becomes 145 lb.

## Information architecture

- [ ] Four tabs, max. Today / History / Library / Me.
- [ ] "Today" is not a dashboard — it's the workout queued up, one tap away from starting.
- [ ] If you have to scroll to start your workout, you've already lost.

## The delight moments that matter

- [ ] The first time you hit a PR, the screen does something unrepeatable — a single subtle thing you won't see again for weeks. Scarcity makes it precious.
- [ ] After the last set, the app says nothing for 2 seconds. Just silence and the final number.
- [ ] Then it transitions to a summary that feels like a receipt from a nice restaurant — sparse, considered, honest about what you did.
- [ ] The streak isn't a number with a flame next to it. It's a quiet calendar with filled circles, and the empty ones don't shame you.

## What to cut

- [ ] Social feeds.
- [ ] Coach chatbots.
- [ ] Onboarding videos.
- [ ] AI form analysis (it's not good enough yet).
- [ ] Gamification with XP and levels.
- [ ] Anything that says "Crush your goals." A workout app that says "Crush" has already failed.
