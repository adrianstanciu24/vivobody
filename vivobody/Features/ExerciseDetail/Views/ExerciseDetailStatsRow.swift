import SwiftUI

struct ExerciseDetailStatsRow: View {
    var body: some View {
        HStack(spacing: 0) {
            VivoStatColumn(
                value: "225lb", label: "1RM PR",
                valueColor: .vivoAccent
            )
            verticalDivider
            VivoStatColumn(value: "48", label: "SESSIONS")
            verticalDivider
            VivoStatColumn(value: "192", label: "TOTAL SETS")
            verticalDivider
            VivoStatColumn(value: "07", label: "LIFETIME PRs")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }
}

#Preview {
    ExerciseDetailStatsRow()
        .background(Color.vivoBackground)
}
