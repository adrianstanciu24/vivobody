import SwiftUI

struct ActiveExerciseCard: View {
    let exercise: SessionExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader
            tagsRow
            divider
            setsList
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.vivoAccent, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", 1))
                .font(.vivoMono(14))
                .foregroundStyle(Color.vivoAccent)

            Text(exercise.name)
                .font(.vivoDisplay(20, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text(exercise.setProgress)
                .font(.vivoMono(12))
                .tracking(1)
                .foregroundStyle(Color.vivoAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.vivoAccent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
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
        .font(.vivoMono(12))
        .tracking(1)
        .padding(.leading, 28)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.leading, 28)
    }

    // MARK: - Sets

    private var setsList: some View {
        VStack(spacing: 0) {
            ForEach(exercise.sets) { exerciseSet in
                setRow(exerciseSet)
            }
        }
    }

    private func setRow(_ exerciseSet: SessionSet) -> some View {
        let isCurrent = !exerciseSet.completed
            && exercise.sets.first(where: { !$0.completed })?.id == exerciseSet.id
        let isPlanned = !exerciseSet.completed && !isCurrent

        return HStack(spacing: 0) {
            Text(String(format: "%02d", exerciseSet.order))
                .font(.vivoMono(12))
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

            if exerciseSet.completed {
                Text("\u{2713}")
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoGreen)
            } else {
                Text("\u{25CB}")
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoSurface)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, isCurrent ? 8 : 0)
        .background(
            isCurrent
                ? RoundedRectangle(cornerRadius: 4)
                .fill(Color.vivoAccent.opacity(0.05))
                : nil
        )

        // Add divider between rows except after current
        .overlay(alignment: .bottom) {
            if !isCurrent, !isPlanned || exerciseSet.order < exercise.totalSets {
                Rectangle()
                    .fill(Color.vivoSurface)
                    .frame(height: 1)
                    .padding(.leading, isCurrent ? 0 : 28)
            }
        }
    }

    private func completedSetText(_ exerciseSet: SessionSet) -> some View {
        HStack(spacing: 0) {
            Text("\(exerciseSet.reps)")
                .font(.vivoMono(15, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" reps · ")
                .font(.vivoMono(15))
                .foregroundStyle(Color.vivoMuted)
            Text("\(exerciseSet.weight)")
                .font(.vivoMono(15, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" lb · RIR \(exerciseSet.rir)")
                .font(.vivoMono(15))
                .foregroundStyle(Color.vivoMuted)
        }
    }

    private func currentSetText(_ exerciseSet: SessionSet) -> some View {
        HStack(spacing: 0) {
            Text("\(exerciseSet.reps)")
                .font(.vivoMono(15, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" reps · ")
                .font(.vivoMono(15))
                .foregroundStyle(Color.vivoPrimary)
            Text("\(exerciseSet.weight)")
                .font(.vivoMono(15, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" lb · RIR ?")
                .font(.vivoMono(15))
                .foregroundStyle(Color.vivoPrimary)
        }
    }

    private func plannedSetText(_ exerciseSet: SessionSet) -> some View {
        Text("\(exerciseSet.reps) reps · \(exerciseSet.weight) lb · planned")
            .font(.vivoMono(15))
            .foregroundStyle(Color.vivoMuted)
    }
}

#Preview {
    let exercise = SessionExercise(
        name: "Barbell Bench Press",
        tags: "CHEST · COMPOUND · BARBELL",
        sets: [
            SessionSet(order: 1, reps: 8, weight: 185, rir: 3, completed: true),
            SessionSet(order: 2, reps: 8, weight: 185, rir: 2, completed: true),
            SessionSet(order: 3, reps: 8, weight: 185, rir: 1),
            SessionSet(order: 4, reps: 8, weight: 185, rir: 0)
        ]
    )
    ActiveExerciseCard(exercise: exercise)
        .background(Color.vivoBackground)
}
