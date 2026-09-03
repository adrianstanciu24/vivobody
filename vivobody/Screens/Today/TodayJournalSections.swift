//
//  TodayJournalSections.swift
//  vivobody
//
//  Focused completed-workout journal leaves for Today's consistency and last
//  workout sections. The root supplies archive-derived values and navigation.
//

import SwiftUI
import VivoKit

struct TodayConsistencySection<Destination: View>: View {
    let workoutDates: Set<Date>
    let prDates: Set<Date>
    let streakText: String?
    private let destination: Destination

    init(
        workoutDates: Set<Date>,
        prDates: Set<Date>,
        streakText: String?,
        @ViewBuilder destination: () -> Destination
    ) {
        self.workoutDates = workoutDates
        self.prDates = prDates
        self.streakText = streakText
        self.destination = destination()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Consistency", trailing: streakText)
            ConsistencyStrip(workoutDates: workoutDates, prDates: prDates)
                .padding(Space.xl)
                .contentCard()
            NavigationLink {
                destination
            } label: {
                HStack {
                    Text("View detail")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(minHeight: Space.tapMin)
                .contentChip()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your consistency details")
        }
    }
}

struct TodayLastWorkoutSection: View {
    let metadata: String
    let durationMinutes: Int
    let receiptStat: Stat
    let totalSets: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Last workout", trailing: metadata)
            StatStrip(
                stats: [
                    Stat(value: "\(durationMinutes)", unit: "min", label: "Time"),
                    receiptStat,
                    Stat(value: "\(totalSets)", label: "Sets"),
                ],
                valueFont: Typography.statValue,
                columnWeights: [3, 4, 3]
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.xl)
            .contentCard()
        }
    }
}
