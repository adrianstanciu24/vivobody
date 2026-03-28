import SwiftUI

struct HistoryView: View {
    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    statsHeader
                    vivoDivider
                    HistoryActivityGrid()
                    vivoDivider
                        .padding(.top, 14)
                    HistoryCalendar()
                    todaySessionCard
                    vivoDivider
                        .padding(.top, 16)
                    recentSessionsSection
                    footerSection
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Stats Header

private extension HistoryView {
    var statsHeader: some View {
        HStack(spacing: 0) {
            headerStat(value: "12", label: "DAY STREAK")
            headerStat(value: "127", label: "TOTAL SESSIONS")
            headerStat(value: "18", label: "THIS MONTH")
            headerStat(value: "42", label: "TOTAL PRs")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
    }

    func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.vivoDisplay(VivoFont.sectionTitle, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(VivoFont.monoMin))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Today Session Card

private extension HistoryView {
    var todaySessionCard: some View {
        HistorySessionCard()
            .padding(.top, 16)
    }
}

// MARK: - Recent Sessions

private extension HistoryView {
    struct RecentSession: Identifiable {
        let id: String
        let day: String
        let month: String
        let name: String
        let detail: String
        let volume: String
        let prText: String?
    }

    static let sessions: [RecentSession] = [
        RecentSession(
            id: "s1",
            day: "17",
            month: "MAR",
            name: "Lower Body A",
            detail: "58 min · 24 sets · 5 exercises",
            volume: "18,240",
            prText: "1 PR"
        ),
        RecentSession(
            id: "s2",
            day: "16",
            month: "MAR",
            name: "Upper Pull B",
            detail: "49 min · 20 sets · 5 exercises",
            volume: "12,650",
            prText: nil
        ),
        RecentSession(
            id: "s3",
            day: "15",
            month: "MAR",
            name: "Upper Push A",
            detail: "51 min · 22 sets · 6 exercises",
            volume: "13,580",
            prText: nil
        ),
        RecentSession(
            id: "s4",
            day: "13",
            month: "MAR",
            name: "Lower Body B",
            detail: "62 min · 26 sets · 6 exercises",
            volume: "21,300",
            prText: "2 PRs"
        )
    ]

    var recentSessionsSection: some View {
        VStack(spacing: 0) {
            Text("RECENT SESSIONS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Self.sessions) { session in
                    HistorySessionRow(
                        day: session.day,
                        month: session.month,
                        name: session.name,
                        detail: session.detail,
                        volume: session.volume,
                        prText: session.prText
                    )
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }
}

// MARK: - Footer

private extension HistoryView {
    static let barcodeHeights: [CGFloat] = [
        16, 10, 16, 5, 14, 16, 4, 12, 16, 8, 16, 10
    ]

    var footerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("VIVOBODY HISTORY · V5.0")
                    .font(.vivoMono(VivoFont.monoMin))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoMuted)
                Text("127 SESSIONS · SINCE SEP 2025")
                    .font(.vivoMono(VivoFont.monoMin))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 1) {
                ForEach(
                    Array(Self.barcodeHeights.enumerated()),
                    id: \.offset
                ) { _, height in
                    Rectangle()
                        .fill(Color.vivoMuted)
                        .frame(width: 1, height: height)
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
