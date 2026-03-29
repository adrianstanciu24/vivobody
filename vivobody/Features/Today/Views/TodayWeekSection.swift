import SwiftUI

// MARK: - Weekly Volume Chart

struct VolumeDay: Identifiable {
    let id: String
    let day: String
    let height: CGFloat
}

extension TodayView {
    static let volumeData: [VolumeDay] = [
        VolumeDay(id: "0", day: "M", height: 0.68),
        VolumeDay(id: "1", day: "T", height: 0.89),
        VolumeDay(id: "2", day: "W", height: 0.59),
        VolumeDay(id: "3", day: "T", height: 0.0),
        VolumeDay(id: "4", day: "F", height: 0.49),
        VolumeDay(id: "5", day: "S", height: 1.0),
        VolumeDay(id: "6", day: "S", height: 0.06)
    ]

    var weeklyVolumeChart: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Self.volumeData) { data in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(
                            data.height > 0
                                ? Color.vivoAccent.opacity(0.3 + data.height * 0.7)
                                : Color.vivoSurface
                        )
                        .frame(height: max(1, data.height * 65))

                    Text(data.day)
                        .font(.vivoMono(VivoFont.monoXS))
                        .foregroundStyle(Color.vivoMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 80)
        .padding(.horizontal, VivoSpacing.screenH)
    }

    var volumeTotals: some View {
        HStack {
            Text("TOTAL: 58,240 LB")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("AVG: 11,648 LB/DAY")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

// MARK: - Recent Sessions

struct RecentSession: Identifiable {
    let id: String
    let name: String
    let stats: String
    let date: String
    let hasPR: Bool
}

extension TodayView {
    static let recentSessions: [RecentSession] = [
        RecentSession(id: "0", name: "Lower Body A", stats: "58 min · 18,240 lb · 1 PR", date: "MAR 17", hasPR: true),
        RecentSession(id: "1", name: "Upper Pull B", stats: "49 min · 12,650 lb", date: "MAR 16", hasPR: false),
        RecentSession(id: "2", name: "Upper Push A", stats: "51 min · 13,580 lb", date: "MAR 15", hasPR: false),
        RecentSession(id: "3", name: "Lower Body B", stats: "62 min · 21,300 lb · 2 PRs", date: "MAR 13", hasPR: true)
    ]

    var recentSessionsList: some View {
        VStack(spacing: 0) {
            ForEach(Self.recentSessions) { session in
                sessionRow(session)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }

    func sessionRow(_ session: RecentSession) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(session.hasPR ? Color.vivoGreen : Color.vivoSurface)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(session.stats)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Text(session.date)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Text("\u{203A}")
                .font(.vivoDisplay(VivoFont.sectionTitle))
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(height: 56)
    }
}

// MARK: - Footer

extension TodayView {
    var footerSection: some View {
        VivoFooter()
    }
}
