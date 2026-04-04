import SwiftData
import SwiftUI

struct EmptyWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(WorkoutSession.self) var session: WorkoutSession?
    @Query(sort: \Exercise.name) var catalogExercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) var workouts: [Workout]
    @State var showExercisePicker = false
    @State var showComplete = false
    @State var selectedQuickPick: Exercise?
    @State var editingExerciseID: UUID?
    @State var showEditSet = false

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
        .sheet(item: $selectedQuickPick) { exercise in
            AddExerciseView(exercise: exercise)
                .environment(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showEditSet) {
            editSetSheet
        }
    }

    private var workoutContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    recordingIndicator
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, VivoSpacing.screenH)
                    statsBar
                    progressSegments
                    divider

                    if hasExercises {
                        activeContent
                        activeBottomBar
                        slideToFinish
                    } else {
                        emptyStateCard
                        quickPicksSection
                    }
                    footerLabel
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(session?.workoutName ?? "Custom Workout")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session?.discard()
                        dismiss()
                    } label: {
                        Text("DISCARD")
                            .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                            .tracking(VivoTracking.tight)
                            .foregroundStyle(Color.vivoMuted)
                    }
                }
            }
        }
    }

    private var slideToFinish: some View {
        SlideToFinishBar {
            session?.finish()
            session?.save()
            showComplete = true
        }
        .padding(.top, 24)
    }
}

// MARK: - Recording Indicator

private extension EmptyWorkoutView {
    var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.vivoAccent)
                .frame(width: 8, height: 8)
            Text("REC")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoAccent)
        }
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
                .padding(.horizontal, 12)

            statItem(
                value: "\(session?.totalVolume ?? 0)",
                label: "VOLUME", suffix: "LB"
            )

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 12)

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
