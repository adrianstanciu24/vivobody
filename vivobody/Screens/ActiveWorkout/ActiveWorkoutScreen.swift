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

struct ActiveWorkoutScreen: View {
    @State private var session: WorkoutSession

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
            Color.black.ignoresSafeArea()

            pager
                .safeAreaInset(edge: .top, spacing: 8) { topBar }
                .safeAreaInset(edge: .bottom, spacing: 10) { bottomBar }

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
                unit: unit.symbol,
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
    /// Summary card). We deliberately do NOT advance the pager to
    /// it — the user just tapped Add from the Summary, so we keep
    /// them on the Summary; the new card is one swipe-left away.
    private func appendExercise(from item: ExerciseCatalogItem) {
        let newExercise = Exercise(
            from: item,
            sortOrder: session.exercises.count
        )
        session.exercises.append(newExercise)
        // Appending an exercise shifts the Summary card one slot to
        // the right. Without this re-anchor, the user would silently
        // end up on the new exercise card instead of staying on
        // Summary where they started.
        session.activeExerciseIndex = session.orderedExercises.count
        Haptics.soft()
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

            Text("\(completedSetCount) / \(totalSetCount)")
                .font(Typography.metricUnit)
                .foregroundStyle(.white.opacity(0.55))

            // Trailing: X — cancel workout (with confirmation alert).
            // Logged sets are lost. To minimize, swipe the sheet
            // down. To finish & archive, swipe to the Summary card
            // and tap Done.
            if onDiscard != nil {
                Button {
                    Haptics.soft()
                    showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        // Visual chip stays compact; outer frame +
                        // contentShape expand the tap area to the
                        // 44pt HIG minimum.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel workout")
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
        .background(Color.black)
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
