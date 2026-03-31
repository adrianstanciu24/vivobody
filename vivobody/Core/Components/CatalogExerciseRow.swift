import SwiftUI

struct CatalogExerciseRow: View {
    let exercise: Exercise
    let number: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(exercise.tags)
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Image(systemName: "plus.circle")
                .font(.system(size: 20))
                .foregroundStyle(Color.vivoAccent)
        }
        .frame(height: 72)
    }
}

#Preview {
    CatalogExerciseRow(
        exercise: Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: "QUADS",
            secondaryTags: "BILATERAL SQUAT · BILATERAL"
        ),
        number: "01"
    )
    .padding(.horizontal, VivoSpacing.screenH)
    .background(Color.vivoBackground)
}
