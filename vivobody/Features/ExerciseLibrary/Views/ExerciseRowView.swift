import SwiftUI

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
            HStack {
                Text(exercise.muscleGroup.displayName)
                Text("\u{00B7}")
                Text(exercise.category.displayName)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
