import SwiftUI

struct HistoryRowView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.startedAt, format: .dateTime.month().day().year())
                .font(.headline)
            HStack {
                Text("\(workout.exercises.count) exercises")
                if let duration = workout.duration {
                    Text("\u{00B7}")
                    Text(
                        Duration.seconds(duration),
                        format: .units(allowed: [.hours, .minutes])
                    )
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
