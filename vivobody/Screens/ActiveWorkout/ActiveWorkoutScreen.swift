//
//  ActiveWorkoutScreen.swift
//  vivobody
//
//  The first real composition. SwipePager hosting one
//  ActiveExerciseCard per exercise; rest-timer overlay above when the
//  session is in a rest interval. The screen owns its WorkoutSession
//  via @State so preview reload doesn't destroy progress mid-tap.
//
//  Open this file in Xcode's canvas and interact directly — adjust
//  weight, tap a set, watch the timer take over, pull to skip, swipe
//  to the next exercise.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutScreen: View {
    @State private var session: WorkoutSession

    /// Read-only access to archived sessions — used to seed a freshly
    /// added exercise with the set count / reps / weight from the
    /// last time the user logged it (see `makeAddedExercise`).
    @Environment(\.modelContext) private var modelContext

    /// Optional archive callback. Wired to the Summary card's DONE
    /// button — that's the canonical "workout is over, save it"
    /// path. Reachable by swiping past the last exercise.
    /// Minimizing the screen (so the user can browse other tabs
    /// while their workout continues) is handled by the sheet's
    /// grabber + drag-down gesture; no screen-wide drag-to-minimize
    /// because vertical-drag controls (NumberScrubber) would
    /// conflict.
    private let onDismiss: (() -> Void)?

    /// Optional discard callback. When provided, the top-bar X
    /// button appears. Tapping it shows a confirmation alert; on
    /// confirm the session is thrown away — any logged sets are
    /// lost. Distinct from `onDismiss`, which archives.
    private let onDiscard: (() -> Void)?

    /// Drives the discard confirmation alert.
    @State private var showDiscardConfirm: Bool = false

    /// Drives the catalog picker for mid-workout exercise add.
    @State private var showAddExercisePicker: Bool = false

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    init(
        session: WorkoutSession = .sample,
        onDismiss: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil
    ) {
        _session = State(wrappedValue: session)
        self.onDismiss = onDismiss
        self.onDiscard = onDiscard
    }

    var body: some View {
        ZStack {
            Surface.background.ignoresSafeArea()

            if isEmpty {
                emptyState
                    .safeAreaInset(edge: .top, spacing: 8) { topBar }
            } else {
                pager
                    .safeAreaInset(edge: .top, spacing: 8) { topBar }
                    .safeAreaInset(edge: .bottom, spacing: 10) { bottomBar }
            }

            if session.isResting {
                RestTimerOverlay(session: session)
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Personal-record celebration. Sits at the highest zIndex
            // so it visually "owns" the screen for its brief moment.
            // Rest timer continues counting underneath; when the user
            // dismisses the celebration they re-emerge into rest
            // already in progress — no time stolen by the ceremony.
            PRCelebration(
                isPresented: prPresentationBinding,
                title: "Personal record",
                value: session.pendingPRValue ?? "",
                unit: session.pendingPRUnit,
                detail: session.pendingPRDetail
            )
            .zIndex(20)
        }
        .animation(.easeOut(duration: 0.18), value: session.isResting)
        // While a PR celebration is on screen, lock the sheet's
        // drag-to-dismiss. Otherwise an accidental downward swipe
        // (muscle memory from skipping the rest timer) collapses the
        // entire workout to the mini-bar mid-ceremony.
        .interactiveDismissDisabled(session.pendingPRValue != nil)
        .onAppear { Haptics.prepare() }
        .alert("Discard this workout?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) {
                Haptics.soft()
                onDiscard?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if session.totalSets > 0 {
                Text("Your \(session.totalSets) logged set\(session.totalSets == 1 ? "" : "s") won't be saved.")
            } else {
                Text("This workout will be removed.")
            }
        }
        .sheet(isPresented: $showAddExercisePicker) {
            ExercisePickerSheet { item in
                appendExercise(from: item)
            }
        }
    }

    // MARK: - Mid-workout add

    /// Append a fresh Exercise from the catalog to the active
    /// session. The new exercise lands at the end (just before the
    /// Summary card).
    private func appendExercise(from item: ExerciseCatalogItem) {
        let wasEmpty = session.orderedExercises.isEmpty
        // Summary lives at index `count` (pages = count + 1); being
        // there means the add came from the Summary card.
        let fromSummary = session.activeExerciseIndex >= session.orderedExercises.count

        let newExercise = makeAddedExercise(
            from: item,
            sortOrder: session.exercises.count
        )
        session.exercises.append(newExercise)

        if wasEmpty || fromSummary {
            // Adding from the empty state or the Summary card: jump
            // straight to the freshly added exercise (now the last
            // card) so the user can start logging it without swiping
            // back.
            session.activeExerciseIndex = session.orderedExercises.count - 1
        }
        // Otherwise the add came from the top-bar chip mid-exercise:
        // leave the pager where it is — earlier indices are
        // unaffected by an append.
        Haptics.soft()
    }

    /// Build the exercise to append. Rather than a blunt "always 3
    /// sets" default, mirror the user's most recent logged version of
    /// this exercise — same number of sets, at the reps and weight
    /// they actually used. A first-time exercise falls back to the
    /// catalog defaults (3 sets at the catalog reps × weight). Either
    /// way the count is then adjustable in the card (+ / − a set).
    private func makeAddedExercise(from item: ExerciseCatalogItem, sortOrder: Int) -> Exercise {
        if let last = mostRecentLoggedExercise(named: item.name) {
            let copy = Exercise.freshCopy(of: last)
            copy.sortOrder = sortOrder
            return copy
        }
        return Exercise(from: item, sortOrder: sortOrder)
    }

    /// The same-named exercise from the most recently completed
    /// session, or nil if the user has never logged it. The current
    /// in-flight session is un-inserted, so it never matches here.
    private func mostRecentLoggedExercise(named name: String) -> Exercise? {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == name }
        )
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        return matches
            .filter { $0.session?.completedAt != nil }
            .max { ($0.session?.completedAt ?? .distantPast) < ($1.session?.completedAt ?? .distantPast) }
    }

    /// Two-way binding for PRCelebration. When the user taps to
    /// dismiss, both pendingPR fields are cleared together —
    /// keeping them in lock-step is what lets `pendingPRValue != nil`
    /// be the single source of truth for "celebration is up."
    private var prPresentationBinding: Binding<Bool> {
        Binding(
            get: { session.pendingPRValue != nil },
            set: { newValue in
                if !newValue {
                    session.pendingPRValue = nil
                    session.pendingPRDetail = nil
                    session.pendingPRUnit = nil
                }
            }
        )
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack(spacing: 0) {
            Text("Active workout")
                .sectionLabelStyle(0.55)

            Spacer()

            // The set tally + mid-workout add are meaningless while
            // the workout is still empty — the empty state owns the
            // single "Add exercise" action there.
            if !isEmpty {
                Text("\(completedSetCount) / \(totalSetCount)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)

                addButton
            }

            // Trailing: X — cancel workout (with confirmation alert).
            // Logged sets are lost. To minimize, swipe the sheet
            // down. To finish & archive, swipe to the Summary card
            // and tap Done.
            if onDiscard != nil {
                discardButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        // Opaque backdrop keeps card content from bleeding through
        // the bar. Previously this overlay also painted a soft
        // black-to-clear gradient ~16pt below itself to suggest the
        // bar floated above the cards — but the carved-glass card
        // upgrade gave every card its own bright top sheen + bevel
        // that already reads as "the bar's edge catches the card's
        // glass." The fade-down overlay was darkening the top of
        // each card on top of that, producing a "bent" crescent.
        // Removed.
        .background(Surface.background)
    }

    /// Compact chip — plus on a tinted circle, matching the discard
    /// X. Lets the user add an exercise without swiping all the way
    /// to the Summary card. Neutral (not lime) so it doesn't compete
    /// with the per-set in-progress accent on the cards below.
    private var addButton: some View {
        Button {
            Haptics.soft()
            showAddExercisePicker = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Ink.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Surface.cardTintBright))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an exercise")
    }

    private var discardButton: some View {
        Button {
            Haptics.soft()
            showDiscardConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Ink.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Surface.cardTintBright))
                // Visual chip stays compact; outer frame +
                // contentShape expand the tap area to the 44pt HIG
                // minimum.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel workout")
    }

    // MARK: - Empty state

    /// Shown when the session has no exercises yet (a fresh, blank
    /// start). The instrument's calm canvas: a type-forward prompt
    /// and one prominent lime action. Tapping Add opens the same
    /// picker used mid-workout; the first pick lands the user on its
    /// card (see `appendExercise`).
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Space.xl)

            Text("New workout")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)

            Text("Empty canvas")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Ink.primary)
                .padding(.top, Space.sm)

            Text("Add your first exercise to start logging sets.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .padding(.top, Space.sm)

            Spacer(minLength: Space.xl)

            addFirstExerciseButton
                .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// The single biggest target on the empty screen — a full-width
    /// lime verb button, the same shape language as the cards' set
    /// buttons. Lime because adding the first exercise IS the live,
    /// in-progress action here.
    private var addFirstExerciseButton: some View {
        Button {
            Haptics.soft()
            showAddExercisePicker = true
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text("Add exercise")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.black)
                Spacer(minLength: 8)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Tint.inProgress)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an exercise")
    }

    private var pager: some View {
        let exercises = session.orderedExercises
        return SwipePager(
            selection: $session.activeExerciseIndex,
            count: exercises.count + 1
        ) { i in
            if i < exercises.count {
                ActiveExerciseCard(
                    exercise: exercises[i],
                    session: session
                )
            } else {
                WorkoutSummaryCard(
                    session: session,
                    onDone: onDismiss,
                    onAddExercise: { showAddExercisePicker = true }
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var bottomBar: some View {
        PageDots(
            count: session.orderedExercises.count + 1,
            selection: session.activeExerciseIndex
        )
        .padding(.bottom, 4)
    }

    // MARK: - Derived

    private var isEmpty: Bool { session.orderedExercises.isEmpty }
    private var completedSetCount: Int { session.totalSets }
    private var totalSetCount: Int     { session.totalPlannedSets }
}

#Preview("Active Workout") {
    ActiveWorkoutScreen()
        .preferredColorScheme(.dark)
}

#Preview("Mid-session") {
    let session = WorkoutSession.sample
    // Pre-complete some sets so the layout shows mixed states.
    if let first = session.orderedExercises.first {
        let setsInOrder = first.orderedSets
        if setsInOrder.count >= 2 {
            setsInOrder[0].isCompleted = true
            setsInOrder[1].isCompleted = true
        }
    }
    return ActiveWorkoutScreen(session: session)
        .preferredColorScheme(.dark)
}
