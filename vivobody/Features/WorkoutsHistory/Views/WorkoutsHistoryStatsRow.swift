import SwiftUI

struct WorkoutsHistoryStatsRow: View {
    let sessions: Int
    let volume: Int
    let thisWeek: Int
    let avgDuration: Int

    private var volumeLabel: String {
        if volume >= 1000 {
            return "\(volume / 1000)K"
        }
        return "\(volume)"
    }

    var body: some View {
        HStack(spacing: 10) {
            VivoStatColumn(
                value: "\(sessions)", label: "SESSIONS",
                valueColor: .vivoAccent
            )
            verticalDivider
            VivoStatColumn(value: volumeLabel, label: "VOL. LB")
            verticalDivider
            VivoStatColumn(value: String(format: "%02d", thisWeek), label: "THIS WEEK")
            verticalDivider
            VivoStatColumn(value: "\(avgDuration)m", label: "AVG DUR.")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }
}

#Preview {
    WorkoutsHistoryStatsRow(sessions: 12, volume: 45000, thisWeek: 3, avgDuration: 42)
        .background(Color.vivoBackground)
}
