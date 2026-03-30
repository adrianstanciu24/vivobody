import SwiftUI

struct ExerciseDetailView: View {
    let exercise: LibraryExercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    divider
                    exerciseTitle
                    tagRow
                    divider
                    ExerciseDetailStatsRow()
                    divider
                    ExerciseDetailVolumeChart()
                    divider
                    ExerciseDetailPRTimeline()
                    divider
                    ExerciseDetailBestSets()
                    divider
                    ExerciseDetailRecentHistory()
                    divider
                    ExerciseDetailFormNotes()
                    VivoFooter(
                        line1: "VIVOBODY WORKOUT SYS",
                        line2: "EXERCISE: \(exercise.name.uppercased())",
                        line3: "48 SESSIONS · SINCE AUG 2024"
                    )
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Text("‹")
                        .font(.vivoDisplay(VivoFont.headlineSM))
                        .foregroundStyle(Color.vivoAccent)
                    Text("LIBRARY")
                        .font(.vivoMono(VivoFont.monoSM))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(Color.vivoAccent)
                }
            }
            Spacer()
            Text("EXERCISE")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Button {} label: {
                Text("EDIT")
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoSecondary)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 12)
        .padding(.bottom, 12)
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
            Text(exercise.primaryTag)
                .foregroundStyle(Color.vivoAccent)
            Text(" · ")
                .foregroundStyle(Color.vivoMuted)
            Text(exercise.secondaryTags)
                .foregroundStyle(Color.vivoMuted)
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
            exercise: ExerciseLibraryView.chestExercises[0]
        )
    }
}
