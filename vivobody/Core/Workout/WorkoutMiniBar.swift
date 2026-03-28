import SwiftUI

struct WorkoutMiniBar: View {
    @Environment(WorkoutSession.self) private var session
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.vivoAccent)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.workoutName.uppercased())
                        .font(.vivoMono(12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.vivoPrimary)
                    Text(session.currentExercise ?? "No exercises yet")
                        .font(.vivoMono(11))
                        .foregroundStyle(Color.vivoMuted)
                }

                Spacer()

                Text(session.elapsedFormatted)
                    .font(.vivoMono(16, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
                    .monospacedDigit()

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.vivoMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.vivoSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}
