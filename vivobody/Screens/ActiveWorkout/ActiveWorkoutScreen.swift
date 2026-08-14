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

import SwiftData
import SwiftUI
import VivoKit

struct ActiveWorkoutScreen: View {
    @State private var session: WorkoutSession

    /// Used only to prime the shared history summary if its background
    /// build has not finished when the user adds an exercise.
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionAnalytics) private var sessionAnalytics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Optional archive callback. Wired to the Summary card's DONE
    /// button — that's the canonical "workout is over, save it"
    /// path. Reachable by swiping past the last exercise.
    /// Minimizing the screen (so the user can browse other tabs
    /// while their workout continues) is handled by the sheet's
    /// grabber + drag-down gesture; no screen-wide drag-to-minimize
    /// because vertical-drag controls (NumberScrubber) would
    /// conflict.
    private let onDismiss: (() -> Void)?

    /// Optional discard callback. When provided, the top-bar X button
    /// appears. Tapping it shows an end-workout alert; logged workouts
    /// can be saved from there, while empty workouts only discard.
    /// Distinct from `onDismiss`, which archives.
    private let onDiscard: (() -> Void)?

    /// AppRoot wires these to WorkoutSessionController so semantic changes
    /// and settled scrubs share the session lifetime. Nil in previews.
    private let onSessionUpdate: (() -> Void)?
    private let onScrubEnded: (() -> Void)?

    /// Drives the discard confirmation alert.
    @State private var showDiscardConfirm: Bool = false

    /// Surfaces failures from draft autosaves while the workout stays
    /// open so the user can retry with their current in-memory state.
    @State private var saveError: SaveErrorBox? = nil

    /// Invalidates every visible scrubber before the workout sheet leaves
    /// or its session is archived/discarded.
    @State private var scrubCancellationID: Int = 0

    /// Drives the catalog picker for exercise adds. Legacy/external
    /// empty drafts initialize it as presented instead of showing a
    /// separate empty-workout screen.
    @State private var showAddExercisePicker: Bool = false

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    init(
        session: WorkoutSession = .sample,
        onDismiss: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil,
        onSessionUpdate: (() -> Void)? = nil,
        onScrubEnded: (() -> Void)? = nil
    ) {
        _session = State(wrappedValue: session)
        _showAddExercisePicker = State(
            initialValue: session.orderedExercises.isEmpty
        )
        self.onDismiss = onDismiss
        self.onDiscard = onDiscard
        self.onSessionUpdate = onSessionUpdate
        self.onScrubEnded = onScrubEnded
    }

    var body: some View {
        ZStack {
            Surface.background.ignoresSafeArea()

            if !isEmpty {
                pager
                    .safeAreaBar(edge: .top, spacing: 8) { topBar }
                    .safeAreaBar(edge: .bottom, spacing: Space.md) { bottomBar }
                    .accessibilityHidden(isBlockingOverlayPresented)
            }

            if session.isResting {
                RestTimerOverlay(
                    session: session,
                    onSessionUpdate: onSessionUpdate
                )
                .transition(.opacity)
                .zIndex(10)
                .accessibilityHidden(session.pendingPRValue != nil)
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: session.isResting)
        // While a PR celebration is on screen, lock the sheet's
        // drag-to-dismiss. Otherwise an accidental downward swipe
        // (muscle memory from skipping the rest timer) collapses the
        // entire workout to the mini-bar mid-ceremony.
        .interactiveDismissDisabled(session.pendingPRValue != nil)
        .onAppear { Haptics.prepare() }
        .onDisappear { finishScrubbing() }
        .onChange(of: session.activeExerciseIndex) { _, _ in
            saveActiveSessionChanges()
        }
        .alert(endWorkoutAlertTitle, isPresented: $showDiscardConfirm) {
            if session.totalSets > 0 {
                Button("Save Workout") {
                    Haptics.soft()
                    finishScrubbing(then: onDismiss)
                }
                Button("Discard", role: .destructive) {
                    Haptics.soft()
                    finishScrubbing(then: onDiscard)
                }
            } else {
                Button("Discard", role: .destructive) {
                    Haptics.soft()
                    finishScrubbing(then: onDiscard)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if session.totalSets > 0 {
                Text("Save \(session.totalSets) logged set\(session.totalSets == 1 ? "" : "s") to History, or discard this workout.")
            } else {
                Text("This workout will be removed.")
            }
        }
        .sheet(
            isPresented: $showAddExercisePicker,
            onDismiss: discardIfStillEmpty
        ) {
            ExercisePickerSheet { item in
                appendExercise(from: item)
            }
        }
        .saveErrorAlert($saveError)
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
        saveActiveSessionChanges()
        Haptics.soft()
    }

    /// Build the exercise to append. Rather than a blunt "always 3
    /// sets" default, mirror the user's most recent logged version of
    /// this exercise — same number of sets, at the reps and weight
    /// they actually used. A first-time exercise falls back to the
    /// catalog defaults (3 sets at the catalog reps × weight). Either
    /// way the count is then adjustable in the card (+ / − a set).
    private func makeAddedExercise(from item: ExerciseCatalogItem, sortOrder: Int) -> Exercise {
        let history = sessionAnalytics?.resolvedExerciseHistory(
            in: modelContext
        )
        let summary = history?[item.historyKey]
        return Exercise.fresh(
            from: item,
            history: summary,
            sortOrder: sortOrder
        )
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        workoutTitle
                        Spacer(minLength: Space.sm)
                        if onDiscard != nil { discardButton }
                    }
                    if !isEmpty {
                        HStack(spacing: Space.sm) {
                            Spacer(minLength: Space.sm)
                            addButton
                        }
                    }
                }
            } else {
                HStack(spacing: Space.sm) {
                    workoutTitle
                    Spacer(minLength: Space.sm)
                    if !isEmpty { addButton }
                    if onDiscard != nil { discardButton }
                }
            }
        }
        // Pull the quiet workout label closer to the sheet's leading edge
        // while the action controls keep their existing trailing alignment.
        .padding(.leading, Space.md)
        .padding(.trailing, Space.gutter)
        .padding(.vertical, 8)
    }

    private var workoutTitle: some View {
        Text("Active workout")
            .sectionLabelStyle(Opacity.medium)
            .accessibilityAddTraits(.isHeader)
    }

    /// Explicitly-labelled chip so this action cannot be mistaken for
    /// the set-count plus inside an exercise card. Neutral (not orange)
    /// so it doesn't compete with the per-set in-progress accent below.
    private var addButton: some View {
        Button {
            Haptics.soft()
            showAddExercisePicker = true
        } label: {
            Label("Exercise", systemImage: "plus")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.md)
                .frame(height: 32)
                .coloredGlassControl(cornerRadius: Radius.pill)
                .frame(minHeight: Space.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an exercise")
    }

    private var discardButton: some View {
        Button {
            Haptics.caution()
            showDiscardConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .frame(width: 26, height: 26)
                .coloredGlassControl(cornerRadius: Radius.pill)
                // Visual chip stays compact; outer frame +
                // contentShape expand the tap area to the 44pt HIG
                // minimum.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.totalSets > 0 ? "End workout" : "Cancel workout")
        .accessibilityInputLabels([Text("End workout"), Text("End"), Text("Finish"), Text("Cancel workout"), Text("Cancel")])
        .accessibilityIdentifier("endWorkoutButton")
    }

    // MARK: - Pager

    private var pager: some View {
        let exercises = session.orderedExercises
        // Slimmer side chrome than the pager's default: the workout
        // card is an instrument read from arm's length, so the width
        // goes to the numerals — a sliver of neighbor peek plus the
        // page dots is enough "there's more" cue.
        return SwipePager(
            selection: $session.activeExerciseIndex,
            count: exercises.count + 1,
            peekWidth: 10,
            spacing: 8
        ) { i in
            if i < exercises.count {
                ActiveExerciseCard(
                    exercise: exercises[i],
                    session: session,
                    onImmediateUpdate: onSessionUpdate,
                    onScrubEnded: onScrubEnded,
                    scrubCancellationID: scrubCancellationID
                )
            } else {
                WorkoutSummaryCard(
                    session: session,
                    onDone: { finishScrubbing(then: onDismiss) },
                    onAddExercise: { showAddExercisePicker = true }
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var bottomBar: some View {
        PageDots(
            count: session.orderedExercises.count + 1,
            selection: $session.activeExerciseIndex,
            linkedRuns: SupersetGrouping.linkedRuns(in: session.orderedExercises)
        )
        .padding(.bottom, 4)
    }

    // MARK: - Derived

    private var isEmpty: Bool {
        session.orderedExercises.isEmpty
    }

    private var isBlockingOverlayPresented: Bool {
        session.isResting || session.pendingPRValue != nil
    }

    private var endWorkoutAlertTitle: String {
        session.totalSets > 0 ? "End this workout?" : "Discard this workout?"
    }

    /// Empty drafts can only come from legacy restoration or an
    /// external start action. They open the picker immediately; if
    /// the picker is cancelled, close the unused draft rather than
    /// exposing a second empty-workout screen.
    private func discardIfStillEmpty() {
        if isEmpty {
            finishScrubbing(then: onDiscard)
        }
    }

    /// Invalidate all child coast tasks before a lifecycle transition. A
    /// minimize/disappear flushes here; archive saves the same in-memory
    /// values itself, while discard intentionally throws them away.
    private func finishScrubbing(then action: (() -> Void)? = nil) {
        scrubCancellationID &+= 1
        if let action {
            action()
        } else {
            onScrubEnded?()
        }
    }

    private func saveActiveSessionChanges() {
        if let onSessionUpdate {
            onSessionUpdate()
            return
        }

        do {
            try modelContext.saveOrRollback()
            SessionSideEffects.handle(.updated, session: session, in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
        }
    }
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
