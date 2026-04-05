import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    @State private var viewModel = ExerciseDetailViewModel()

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    exerciseTitle
                    tagRow

                    if let profile = viewModel.profile {
                        divider
                        ExerciseDetailMuscleTargetsView(targets: profile.targets.all)
                        divider
                        ExerciseDetailTopMusclesView(muscles: profile.topMuscles)
                        divider
                        ExerciseDetailJointDemandView(
                            jointStress: profile.demands.jointStress,
                            kneeVsHip: profile.biases.kneeVsHip
                        )
                        divider
                        ExerciseDetailRangeOfMotionView(rangeOfMotion: profile.kinematics.rangeOfMotion)
                        divider
                        ExerciseDetailMovementProfileView(
                            stability: profile.demands.stability,
                            tempoSensitivity: profile.demands.tempoSensitivity,
                            repDurationSec: profile.exercise.repDurationSec,
                            movementTags: profile.exercise.movementTags
                        )
                        divider
                        ExerciseDetailStretchProfileView(stretch: profile.biases.stretch)
                        divider
                        ExerciseDetailPhaseBreakdownView(
                            phases: profile.demands.phaseBreakdown,
                            phaseWindows: profile.kinematics.phaseWindows
                        )
                    }

                    divider
                    ExerciseDetailStatsRow()
                    divider
                    ExerciseDetailVolumeChart()
                    divider
                    ExerciseDetailPRTimeline()
                    divider
                    ExerciseDetailBestSetsView()
                    divider
                    ExerciseDetailRecentHistoryView()
                    divider
                    ExerciseDetailFormNotesView()
                    VivoFooter(
                        line1: "VIVOBODY WORKOUT SYS",
                        line2: "EXERCISE: \(exercise.name.uppercased())",
                        line3: "48 SESSIONS · SINCE AUG 2024"
                    )
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EXERCISE")
                    .font(.vivoMono(VivoFont.monoXS))
                    .tracking(VivoTracking.wide)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .onAppear { viewModel.loadProfile(for: exercise) }
    }

    private var exerciseTitle: some View {
        HStack {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.titleLG, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var tagRow: some View {
        HStack(spacing: 0) {
            Text(exercise.primaryTag.isEmpty ? exercise.muscleGroup.displayName.uppercased() : exercise.primaryTag)
                .foregroundStyle(Color.vivoAccent)
            if !exercise.secondaryTags.isEmpty {
                Text(" · ")
                    .foregroundStyle(Color.vivoMuted)
                Text(exercise.secondaryTags)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .font(.vivoMono(VivoFont.monoSM))
        .tracking(VivoTracking.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            exercise: Exercise(
                catalogID: "front_squat",
                name: "Front Squat",
                muscleGroup: .legs,
                category: .barbell,
                primaryTag: "QUADS",
                secondaryTags: "BILATERAL SQUAT · BILATERAL"
            )
        )
    }
}
