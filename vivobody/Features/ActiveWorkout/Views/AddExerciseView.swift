import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSession.self) private var session: WorkoutSession?

    let exercise: Exercise

    @State var reps = 8
    @State var load = 185
    @State var rir = 2
    @State var rom = "FULL"
    @State var tempo = "CONTROLLED"
    @State var grip = "NORMAL"
    @State var stance = "NORMAL"
    @State var loggedSets: [LoggedSet] = []
    @State var showAdvanced = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vivoBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        exerciseSubtitle
                        sectionLabel("SET CONFIGURATION")
                        setConfiguration
                        recentLoads
                        divider
                        sectionLabel("REPS IN RESERVE")
                        rirControl
                        divider
                        advancedToggle
                        if showAdvanced {
                            advancedOptions
                            divider
                        }
                        logSetButton
                        loggedSetsSection
                        footerInfo
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !loggedSets.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Discard", role: .destructive) { dismiss() }
                            .tint(Color.vivoMuted)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { saveAndDismiss() } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .tint(Color.vivoAccent)
                }
            }
            .interactiveDismissDisabled(!loggedSets.isEmpty)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }
}

// MARK: - Save Action

private extension AddExerciseView {
    func saveAndDismiss() {
        let sets = loggedSets.enumerated().map { index, logged in
            SessionSet(
                order: index + 1,
                reps: logged.reps,
                weight: logged.load,
                rir: logged.rir,
                rom: logged.rom,
                tempo: logged.tempo,
                grip: logged.grip,
                stance: logged.stance,
                completed: true
            )
        }
        session?.addExercise(exercise, sets: sets)
        dismiss()
    }
}

// MARK: - Exercise Subtitle

private extension AddExerciseView {
    var exerciseSubtitle: some View {
        ExerciseNameTagRow(
            name: exercise.name,
            primaryTag: exercise.primaryTag,
            secondaryTags: exercise.secondaryTags,
            showPrimaryTag: false,
            nameFont: VivoFont.titleXL
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }
}

// MARK: - Preview

#Preview {
    AddExerciseView(
        exercise: Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: "QUADS",
            secondaryTags: "BILATERAL SQUAT · BILATERAL"
        )
    )
    .environment(WorkoutSession())
}
