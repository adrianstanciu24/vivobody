import SwiftUI

struct ActiveExerciseCard: View {
    let exercise: SessionExercise
    let number: Int
    var restSecondsRemaining: Int = 0
    var onLogSet: (() -> Void)?
    var onEditSet: (() -> Void)?
    var onSkipRest: (() -> Void)?

    private var hasUncompletedSets: Bool {
        exercise.sets.contains(where: { !$0.completed })
    }

    private var allSetsCompleted: Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy(\.completed)
    }

    private var showRestTimer: Bool {
        restSecondsRemaining > 0 && exercise.restTimerVisible
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader
            tagsRow
            divider
            setsList
            if showRestTimer {
                inlineRestTimer
            }
            if hasUncompletedSets {
                actionButtons
            } else if allSetsCompleted {
                editCompletedButton
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoAccent, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .padding(.horizontal, VivoSpacing.screenH)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", number))
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoAccent)

            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.headlineSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text(exercise.setProgress)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .fill(Color.vivoAccent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: VivoRadius.badge)
                                .stroke(Color.vivoAccent, lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Tags

    private var tagsRow: some View {
        HStack(spacing: 0) {
            Text(exercise.tags.components(separatedBy: " · ").first ?? "")
                .foregroundStyle(Color.vivoAccent)
            if exercise.tags.contains(" · ") {
                let remaining = exercise.tags.components(separatedBy: " · ")
                    .dropFirst().joined(separator: " · ")
                Text(" · \(remaining)")
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .font(.vivoMono(VivoFont.monoSM))
        .tracking(VivoTracking.normal)
        .padding(.leading, 28)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.leading, 28)
    }

    // MARK: - Sets

    private var setsList: some View {
        VStack(spacing: 4) {
            ForEach(exercise.sets) { exerciseSet in
                setRow(exerciseSet)
            }
        }
        .padding(.top, 6)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button { onLogSet?() } label: {
                Text("LOG SET \(String(format: "%02d", exercise.currentSetNumber))")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.vivoAccent)
                    .clipShape(RoundedRectangle(cornerRadius: VivoRadius.badge))
            }

            Button { onEditSet?() } label: {
                Text("EDIT")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoAccent)
                    .frame(width: 64)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.badge)
                            .stroke(Color.vivoAccent, lineWidth: 1.5)
                    )
            }
        }
        .padding(.top, 10)
    }

    private var editCompletedButton: some View {
        Button { onEditSet?() } label: {
            Text("EDIT")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoAccent, lineWidth: 1.5)
                )
        }
        .padding(.top, 10)
    }

    private func setRow(_ exerciseSet: SessionSet) -> some View {
        let isCurrent = !exerciseSet.completed
            && exercise.sets.first(where: { !$0.completed })?.id == exerciseSet.id
        let isPlanned = !exerciseSet.completed && !isCurrent

        return HStack(spacing: 0) {
            Text(String(format: "%02d", exerciseSet.order))
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 28, alignment: .leading)

            if exerciseSet.completed {
                completedSetText(exerciseSet)
            } else if isCurrent {
                currentSetText(exerciseSet)
            } else {
                plannedSetText(exerciseSet)
            }

            Spacer()

            setTrailingAction(isCompleted: exerciseSet.completed)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            isCurrent
                ? RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color.vivoAccent.opacity(0.05))
                : nil
        )
        .overlay(alignment: .bottom) {
            if !isCurrent {
                Rectangle()
                    .fill(Color.vivoSurface)
                    .frame(height: 1)
                    .padding(.leading, 36)
            }
        }
    }
}

#Preview {
    let exercise = SessionExercise(
        catalogID: "front_squat",
        name: "Front Squat",
        primaryTag: "QUADS",
        secondaryTags: "BILATERAL SQUAT · BILATERAL",
        muscleGroup: .legs,
        sets: [
            SessionSet(order: 1, reps: 8, weight: 185, rir: 3, completed: true),
            SessionSet(order: 2, reps: 8, weight: 185, rir: 2, completed: true),
            SessionSet(order: 3, reps: 8, weight: 185, rir: 1),
            SessionSet(order: 4, reps: 8, weight: 185, rir: 0)
        ],
        targetRestSeconds: 120
    )
    ActiveExerciseCard(exercise: exercise, number: 1, restSecondsRemaining: 87)
        .background(Color.vivoBackground)
}
