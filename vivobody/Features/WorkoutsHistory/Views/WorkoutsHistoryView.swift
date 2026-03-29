import SwiftUI

struct WorkoutsHistoryView: View {
    @State private var selectedFilter = "ALL"

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    WorkoutsHistoryHeader()
                    divider
                    WorkoutsHistoryFilterPills(selectedFilter: $selectedFilter)
                    divider

                    WorkoutsHistoryWeekSection(
                        label: "THIS WEEK",
                        sessions: Self.thisWeekSessions,
                        highlightFirst: true
                    )
                    divider
                    WorkoutsHistoryWeekSection(
                        label: "LAST WEEK",
                        sessions: Self.lastWeekSessions
                    )
                    divider
                    WorkoutsHistoryWeekSection(
                        label: "MAR 02 \u{2014} MAR 08",
                        sessions: Self.olderSessions
                    )

                    divider
                    VivoFooter()
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Header

struct WorkoutsHistoryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WORKOUT LOG")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 12)

            Text("Workouts")
                .font(.vivoDisplay(VivoFont.titleLG, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
                .padding(.top, 4)

            HStack(spacing: 0) {
                VivoStatColumn(
                    value: "127", label: "SESSIONS",
                    valueColor: .vivoAccent
                )
                verticalDivider
                VivoStatColumn(value: "48K", label: "VOL. LB")
                verticalDivider
                VivoStatColumn(value: "07", label: "PRs")
                verticalDivider
                VivoStatColumn(value: "12", label: "STREAK")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 12)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }
}

// MARK: - Filter Pills

struct WorkoutsHistoryFilterPills: View {
    @Binding var selectedFilter: String
    private let filters = ["ALL", "PUSH", "PULL", "LEGS", "FULL"]

    var body: some View {
        HStack(spacing: 20) {
            ForEach(filters, id: \.self) { filter in
                Button { selectedFilter = filter } label: {
                    Text(filter)
                        .font(.vivoMono(
                            VivoFont.monoSM,
                            weight: selectedFilter == filter ? .bold : .regular
                        ))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(
                            selectedFilter == filter ? Color.vivoAccent : Color.vivoMuted
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(pillBackground(selected: selectedFilter == filter))
                }
            }
            Spacer()
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func pillBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color.vivoAccent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoAccent, lineWidth: 1)
                )
        }
    }
}

// MARK: - Week Section

struct WorkoutsHistoryWeekSection: View {
    let label: String
    let sessions: [HistorySession]
    var highlightFirst = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                WorkoutSessionRow(
                    session: session,
                    highlight: highlightFirst && index == 0
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutsHistoryView()
}
