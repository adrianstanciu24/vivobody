import SwiftUI

struct ExerciseLibraryRow: View {
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
                Text(
                    "\(Text(exercise.primaryTag).foregroundStyle(Color.vivoAccent))\(Text(" · \(exercise.secondaryTags)").foregroundStyle(Color.vivoMuted))"
                )
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text("›")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)
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
