import SwiftUI

struct ExerciseLibraryRow: View {
    let exercise: Exercise
    let number: String
    var showPrimaryTag = true

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 18, alignment: .leading)

            ExerciseNameTagRow(
                name: exercise.name,
                primaryTag: exercise.primaryTag,
                secondaryTags: exercise.secondaryTags,
                showPrimaryTag: showPrimaryTag
            )

            Spacer()

            Text("›")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)
                .accessibilityHidden(true)
        }
        .frame(height: 72)
    }
}

#Preview {
    VStack {
        ExerciseLibraryRow(
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
        ExerciseLibraryRow(
            exercise: Exercise(
                catalogID: "romanian_deadlift",
                name: "Romanian Deadlift",
                muscleGroup: .legs,
                category: .barbell,
                primaryTag: "GLUTES",
                secondaryTags: "HIP HINGE · BILATERAL"
            ),
            number: "02"
        )
    }
    .padding(.horizontal, VivoSpacing.screenH)
    .background(Color.vivoBackground)
}
