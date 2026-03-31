import SwiftData
import SwiftUI

struct EmptyWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutSession.self) var session: WorkoutSession?
    @Query(sort: \Exercise.name) var catalogExercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) var workouts: [Workout]
    @State var showExercisePicker = false
    @State var showComplete = false

    private var hasExercises: Bool {
        session?.exercises.isEmpty == false
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            if showComplete {
                WorkoutCompleteView {
                    session?.reset()
                    showComplete = false
                    dismiss()
                }
            } else {
                workoutContent
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView()
                .environment(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var workoutContent: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        recordingHeader
                        workoutTitle
                        statsBar
                        progressSegments
                        divider

                        if hasExercises {
                            activeContent
                        } else {
                            emptyStateCard
                            quickPicksSection
                        }
                        footerLabel
                    }
                    .padding(.bottom, hasExercises ? 100 : 32)
                }
                .scrollIndicators(.hidden)

                Spacer(minLength: 0)
            }

            if hasExercises {
                VStack {
                    Spacer()
                    activeBottomBar
                }
            }
        }
    }
}

// MARK: - Recording Header

private extension EmptyWorkoutView {
    var recordingHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.vivoAccent)
                    .frame(width: 8, height: 8)
                Text("RECORDING")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.wide)
                    .foregroundStyle(Color.vivoAccent)
            }

            Spacer()

            Button {
                session?.discard()
                dismiss()
            } label: {
                Text("DISCARD")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }

            Button {
                session?.finish()
                session?.save()
                showComplete = true
            } label: {
                Text("FINISH \u{2192}")
                    .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoAccent)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
    }
}

// MARK: - Workout Title

private extension EmptyWorkoutView {
    var workoutTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Custom")
                .font(.vivoDisplay(VivoFont.titleLG, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text("Workout")
                .font(.vivoDisplay(VivoFont.titleLG, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text("ADD MOVES ON THE FLY · SAVES AUTOMATICALLY")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
    }
}

// MARK: - Stats Bar

private extension EmptyWorkoutView {
    var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: session?.elapsedFormatted ?? "00:00", label: "ELAPSED")

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1, height: 28)

            statItem(
                value: "\(session?.totalVolume ?? 0)",
                label: "VOLUME", suffix: "LB"
            )

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1, height: 28)

            statItem(value: "\(session?.setsDone ?? 0)", label: "SETS DONE")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 10)
    }

    func statItem(value: String, label: String, suffix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.vivoDisplay(VivoFont.headlineMD, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                if let suffix {
                    Text(suffix)
                        .font(.vivoMono(VivoFont.monoXS))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                        .offset(y: 4)
                }
            }
            Text(label)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Progress Segments

private extension EmptyWorkoutView {
    var progressSegments: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< 6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: VivoRadius.dot)
                    .fill(Color.vivoSurface)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 12)
    }

    var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 14)
    }
}

// MARK: - Empty State Card

private extension EmptyWorkoutView {
    var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoAccent, lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("+")
                            .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                            .foregroundStyle(Color.vivoAccent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("NO EXERCISES YET")
                        .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(Color.vivoAccent)
                    Text("Build this session as you go, or pull something in from a template.")
                        .font(.vivoMono(VivoFont.monoCaption))
                        .lineSpacing(2)
                        .foregroundStyle(Color.vivoMuted)
                }
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.bottom, 16)

            instructionRow(number: "01", title: "ADD YOUR FIRST EXERCISE",
                           detail: "Search, browse recent lifts, or create one from scratch.")
                .padding(.bottom, 14)

            instructionRow(number: "02", title: "SET REPS / LOAD / RIR",
                           detail: "Use the same TE control panel style as the add-exercise flow.")
                .padding(.bottom, 16)

            Button { showExercisePicker = true } label: {
                Text("+ ADD FIRST EXERCISE")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.vivoAccent)
                    .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                    .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
            }
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoAccent, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 14)
    }

    func instructionRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoMuted)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoPrimary)
                Text(detail)
                    .font(.vivoMono(VivoFont.monoCaption))
                    .lineSpacing(2)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmptyWorkoutView()
    }
    .modelContainer(
        for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
        inMemory: true
    )
}
