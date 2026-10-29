//
//  TodayJournalSections.swift
//  vivobody
//
//  Focused completed-workout journal leaves for Today's consistency and last
//  workout sections. The root supplies archive-derived values and navigation.
//  Before the first archived workout both sections keep their layout, with
//  empty days and placeholder values.
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
    struct Summary {
        let metadata: String
        let durationMinutes: Int
        let receiptStat: Stat
        let totalSets: Int
    }

    /// Nil before the first archived workout.
    let summary: Summary?
    let unit: WeightUnit

    private static let placeholderCaption = "Finish a workout to see its time, volume, and sets."

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Last workout", trailing: summary?.metadata ?? "None yet")
            if let summary {
                strip([
                    Stat(value: "\(summary.durationMinutes)", unit: "min", label: "Time"),
                    summary.receiptStat,
                    Stat(value: "\(summary.totalSets)", label: "Sets"),
                ])
                .padding(Space.xl)
                .contentCard()
            } else {
                placeholder
            }
        }
    }

    private func strip(_ stats: [Stat]) -> some View {
        StatStrip(
            stats: stats,
            valueFont: Typography.statValue,
            columnWeights: [3, 4, 3]
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            strip([
                Stat(value: nil, unit: "min", label: "Time"),
                Stat(value: nil, unit: unit.symbol, label: "Volume"),
                Stat(value: nil, label: "Sets"),
            ])
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
            Text(Self.placeholderCaption)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .contentCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No workouts yet. \(Self.placeholderCaption)")
        .accessibilityIdentifier("todayLastWorkoutPlaceholder")
    }
}

#Preview("Today placeholders") {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                TodayUpNextPlaceholder()
                SectionDivider()
                TodayConsistencySection(workoutDates: [], prDates: [], streakText: nil) {
                    Text("Consistency")
                }
                SectionDivider()
                TodayLastWorkoutSection(summary: nil, unit: .lb)
            }
            .padding(.horizontal, Space.gutter)
        }
        .screenBackground()
    }
    .preferredColorScheme(.dark)
}
