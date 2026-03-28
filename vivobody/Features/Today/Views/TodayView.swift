import SwiftUI

struct TodayView: View {
    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    greetingHeader
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
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(12))
            .tracking(2)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }
}

// MARK: - Greeting & Date

private extension TodayView {
    var greetingHeader: some View {
        HStack {
            Text("GOOD MORNING, ALEX")
                .font(.vivoMono(12))
                .tracking(1.5)
                .foregroundStyle(Color.vivoSecondary)

            Spacer()

            Circle()
                .fill(Color.vivoSurface)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("AS")
                        .font(.vivoMono(11, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                )
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    var bigDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Wednesday")
                .font(.vivoDisplay(34, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text("March 18")
                .font(.vivoDisplay(34, weight: .bold))
                .foregroundStyle(Color.vivoSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }

    var sessionInfo: some View {
        Text("SESSION #128 TODAY · WEEK 12")
            .font(.vivoMono(12))
            .tracking(1)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    func statItem(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.vivoDisplay(24, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(10))
                .tracking(1)
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
                        .font(.vivoMono(12))
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
                        .font(.vivoMono(10))
                        .foregroundStyle(Color.vivoMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
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
