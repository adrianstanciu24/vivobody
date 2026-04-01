import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WorkoutDetailViewModel?
    let workout: Workout

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                detailHeader
                divider

                if let viewModel {
                    ScrollView {
                        VStack(spacing: 0) {
                            statsRow
                            divider
                            notesSection(viewModel: viewModel)
                            divider
                            exercisesList(viewModel: viewModel)
                            VivoFooter()
                        }
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = WorkoutDetailViewModel(
                    modelContext: persistence.modelContext,
                    workout: workout
                )
            }
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Text("\u{2190}")
                            .font(.vivoDisplay(VivoFont.body))
                        Text("BACK")
                            .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                            .tracking(VivoTracking.normal)
                    }
                    .foregroundStyle(Color.vivoAccent)
                }

                Spacer()

                if let viewModel {
                    if viewModel.isEditing {
                        Button {
                            viewModel.cancelEditing()
                        } label: {
                            Text("CANCEL")
                                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                                .tracking(VivoTracking.tight)
                                .foregroundStyle(Color.vivoMuted)
                        }

                        Button {
                            viewModel.saveEdits()
                        } label: {
                            Text("SAVE")
                                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                                .tracking(VivoTracking.tight)
                                .foregroundStyle(Color.vivoAccent)
                        }
                        .padding(.leading, 12)
                    } else {
                        Button {
                            viewModel.startEditing()
                        } label: {
                            Text("EDIT")
                                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                                .tracking(VivoTracking.tight)
                                .foregroundStyle(Color.vivoAccent)
                        }
                    }
                }
            }

            Text(workout.notes.isEmpty ? "Custom Workout" : workout.notes)
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text(workout.formattedDate)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            VivoStatColumn(
                value: workout.durationFormatted,
                label: "DURATION"
            )
            verticalDivider
            VivoStatColumn(
                value: workout.volumeFormatted,
                label: "VOLUME"
            )
            verticalDivider
            VivoStatColumn(
                value: workout.setsFormatted,
                label: "TOTAL SETS"
            )
            verticalDivider
            VivoStatColumn(
                value: "\(workout.exerciseCount)",
                label: "EXERCISES"
            )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }

    // MARK: - Notes

    private func notesSection(viewModel: WorkoutDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)

            if viewModel.isEditing {
                TextField(
                    "Add workout notes...",
                    text: Binding(
                        get: { viewModel.editedNotes },
                        set: { viewModel.editedNotes = $0 }
                    )
                )
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoPrimary)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.card)
                        .stroke(Color.vivoAccent, lineWidth: 1)
                )
            } else {
                Text(workout.notes.isEmpty ? "No notes" : workout.notes)
                    .font(.vivoMono(VivoFont.monoMD))
                    .foregroundStyle(
                        workout.notes.isEmpty ? Color.vivoMuted : Color.vivoPrimary
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    // MARK: - Exercises List

    private func exercisesList(viewModel: WorkoutDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXERCISES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(
                Array(viewModel.sortedExercises.enumerated()),
                id: \.element.persistentModelID
            ) { index, workoutExercise in
                WorkoutDetailExerciseCard(
                    workoutExercise: workoutExercise,
                    number: index + 1,
                    isEditing: viewModel.isEditing,
                    onUpdateSet: { exerciseSet, reps, weight in
                        viewModel.updateSet(exerciseSet, reps: reps, weight: weight)
                    },
                    onDelete: {
                        viewModel.deleteExercise(workoutExercise)
                    }
                )
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.bottom, 12)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Workout Formatted Date

private extension Workout {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: startedAt).uppercased()
    }
}

// MARK: - Exercise Card

struct WorkoutDetailExerciseCard: View {
    let workoutExercise: WorkoutExercise
    let number: Int
    let isEditing: Bool
    let onUpdateSet: (ExerciseSet, Int?, Double?) -> Void
    let onDelete: () -> Void

    private var sortedSets: [ExerciseSet] {
        workoutExercise.sets.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseHeader
            divider
            setsList
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
    }

    private var exerciseHeader: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", number))
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(workoutExercise.displayName)
                    .font(.vivoDisplay(VivoFont.headlineSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)

                if !workoutExercise.exercisePrimaryTagSnapshot.isEmpty {
                    Text(workoutExercise.exercisePrimaryTagSnapshot)
                        .font(.vivoMono(VivoFont.monoSM))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                }
            }

            Spacer()

            if isEditing {
                Button(action: onDelete) {
                    Text("\u{2715}")
                        .font(.vivoDisplay(VivoFont.body))
                        .foregroundStyle(Color.vivoAccent)
                }
            } else {
                Text("\(sortedSets.filter(\.isCompleted).count)/\(sortedSets.count)")
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: VivoRadius.badge)
                            .fill(Color.vivoGreen.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: VivoRadius.badge)
                                    .stroke(Color.vivoGreen, lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.bottom, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.leading, 28)
    }

    private var setsList: some View {
        VStack(spacing: 0) {
            ForEach(sortedSets) { exerciseSet in
                setRow(exerciseSet)
            }
        }
    }

    private func setRow(_ exerciseSet: ExerciseSet) -> some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d", exerciseSet.order + 1))
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 28, alignment: .leading)

            if exerciseSet.isCompleted {
                HStack(spacing: 0) {
                    Text("\(exerciseSet.reps ?? 0)")
                        .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                    Text(" reps \u{00B7} ")
                        .font(.vivoMono(VivoFont.monoBody))
                        .foregroundStyle(Color.vivoMuted)
                    Text(String(format: "%.0f", exerciseSet.weight ?? 0))
                        .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                    Text(" lb")
                        .font(.vivoMono(VivoFont.monoBody))
                        .foregroundStyle(Color.vivoMuted)
                }
            } else {
                Text("skipped")
                    .font(.vivoMono(VivoFont.monoBody))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            if exerciseSet.isCompleted {
                Text("\u{2713}")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoGreen)
            } else {
                Text("\u{25CB}")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoSurface)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.leading, 28)
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutDetailView(workout: Workout(startedAt: .now, notes: "Push Day"))
        .withPersistence()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
