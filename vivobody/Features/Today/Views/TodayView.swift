import SwiftUI

struct TodayView: View {
    let navInset: CGFloat = 20

    private var dateLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide)) + ", "
            + Date.now.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vivoBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        bigDate
                        sessionInfo
                        statsRow
                        weekStrip
                        sectionDivider
                        sectionHeader("UP NEXT")
                        TodayHeroCard()
                        sectionDivider
                        sectionHeader("WEEKLY VOLUME")
                        weeklyVolumeChart
                        volumeTotals
                        sectionDivider
                        sectionHeader("RECENT SESSIONS")
                        recentSessionsList
                        footerSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Today")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, navInset)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, navInset)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }
}

// MARK: - Greeting & Date

private extension TodayView {
    var bigDate: some View {
        Text(dateLabel)
            .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
            .foregroundStyle(Color.vivoSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, navInset)
            .padding(.top, 2)
    }

    var sessionInfo: some View {
        Text("SESSION #128 TODAY · WEEK 12")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.normal)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, navInset)
            .padding(.top, 4)
            .padding(.bottom, 14)
    }
}

// MARK: - Stats Row

private extension TodayView {
    var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "12", label: "DAY STREAK")
            statItem(value: "04", label: "THIS WEEK")
            statItem(value: "86%", label: "ADHERENCE")
            statItem(value: "42", label: "TOTAL PRs")
        }
        .padding(.horizontal, navInset)
        .padding(.vertical, 14)
    }

    func statItem(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.vivoDisplay(VivoFont.headlineLG, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week Day Strip

struct WeekDayItem: Identifiable {
    let id: String
    let letter: String
    let date: String
    let active: Bool
    let today: Bool
}

private extension TodayView {
    static let weekDays: [WeekDayItem] = [
        WeekDayItem(id: "0", letter: "M", date: "12", active: true, today: false),
        WeekDayItem(id: "1", letter: "T", date: "13", active: true, today: false),
        WeekDayItem(id: "2", letter: "W", date: "14", active: true, today: false),
        WeekDayItem(id: "3", letter: "T", date: "15", active: true, today: false),
        WeekDayItem(id: "4", letter: "F", date: "16", active: false, today: false),
        WeekDayItem(id: "5", letter: "S", date: "17", active: true, today: false),
        WeekDayItem(id: "6", letter: "S", date: "18", active: false, today: true)
    ]

    var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekDays) { day in
                VStack(spacing: 6) {
                    Text(day.letter)
                        .font(.vivoMono(VivoFont.monoSM))
                        .foregroundStyle(Color.vivoMuted)

                    Circle()
                        .fill(dayFill(day))
                        .frame(width: 20, height: 20)
                        .overlay(
                            day.today
                                ? Circle().stroke(Color.vivoAccent, lineWidth: 1.5)
                                : nil
                        )

                    Text(day.date)
                        .font(.vivoMono(VivoFont.monoXS))
                        .foregroundStyle(Color.vivoMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, navInset)
        .padding(.vertical, 14)
    }

    func dayFill(_ day: WeekDayItem) -> Color {
        if day.today {
            return Color.vivoSurface
        }
        return day.active ? Color.vivoAccent : Color.vivoSurface
    }
}

// MARK: - Preview

#Preview {
    TodayView()
}
