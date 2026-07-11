//
//  PersonalRecordsScreen.swift
//  vivobody
//
//  The full PR wall, pushed from the Me tab. Every tracked lift's
//  standing record — heaviest set (or longest hold for timed work) —
//  ordered by how recently it was set, so fresh achievements lead.
//  Records set in the last 30 days wear the accent.
//

import VivoKit
import SwiftUI
import SwiftData

struct PersonalRecordsScreen: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    private var records: [ExerciseProgress] { completedSessions.personalRecords }

    var body: some View {
        ScrollView {
            if records.isEmpty {
                ContentUnavailableView(
                    "No records yet",
                    systemImage: "trophy",
                    description: Text("Log an exercise across two or more sessions and your best set lands here.")
                )
                .padding(.top, Space.section)
            } else {
                VStack(spacing: Space.sm) {
                    ForEach(records) { record in
                        PRRow(record: record, unit: weightUnit)
                    }
                }
                .padding(.top, Space.sm)
                .padding(.bottom, Space.section + Space.md)
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .detailForgeBackground()
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One PR-wall row: exercise name + group/date subtitle, standing
/// record on the right. Shared shape between the wall and the Me-tab
/// preview so a record reads identically in both places.
struct PRRow: View {
    let record: ExerciseProgress
    let unit: WeightUnit

    private var isRecent: Bool {
        guard let date = record.recordDate else { return false }
        return date >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantFuture
    }

    var body: some View {
        KitRow(
            title: record.name,
            subtitle: subtitle
        ) {
            // The weight is the record; the reps/hold only qualify it.
            // Splitting the hierarchy (huge weight, small dim
            // qualifier) keeps the trailing value on ONE line — the
            // old single statValue string wrapped mid-value next to
            // long exercise names, centering "× 12" under the weight.
            HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                if isRecent {
                    Image(systemName: "sparkles")
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primary)
                }
                Text(headlineValue)
                    .font(Typography.statValue)
                    .foregroundStyle(isRecent ? Tint.primary : Ink.primary)
                    .monospacedDigit()
                if let qualifier = qualifierValue {
                    Text(qualifier)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.tertiary)
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PRRow.recordValue(record, unit: unit))
        }
    }

    /// The big numeral: the record's weight, or the hold time when
    /// the exercise is an unloaded timed hold.
    private var headlineValue: String {
        guard let point = record.recordPoint else { return "—" }
        switch record.trackingMode {
        case .reps:
            return WeightFormatter.string(point.topWeight, unit: unit, includeUnit: false)
        case .duration:
            guard point.topWeight > 0 else { return DurationFormatter.string(point.topDuration) }
            return WeightFormatter.string(point.topWeight, unit: unit, includeUnit: false)
        }
    }

    /// The small dim qualifier ("× 12", "× 0:45"); nil when the
    /// headline already says everything (bare hold, no record).
    private var qualifierValue: String? {
        guard let point = record.recordPoint else { return nil }
        switch record.trackingMode {
        case .reps:
            return "× \(point.topReps)"
        case .duration:
            guard point.topWeight > 0 else { return nil }
            return "× \(DurationFormatter.string(point.topDuration))"
        }
    }

    private var subtitle: String {
        var parts = [record.group.displayName]
        if let date = record.recordDate {
            parts.append(RelativeDate.short(date))
        }
        return parts.joined(separator: " · ")
    }

    /// Mode-aware standing record: "145 × 8" for reps, "1:30" for a
    /// hold (or "25 × 0:45" when the hold is loaded).
    static func recordValue(_ record: ExerciseProgress, unit: WeightUnit) -> String {
        guard let point = record.recordPoint else { return "—" }
        switch record.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(point.topWeight, unit: unit, includeUnit: false)) × \(point.topReps)"
        case .duration:
            let time = DurationFormatter.string(point.topDuration)
            guard point.topWeight > 0 else { return time }
            return "\(WeightFormatter.string(point.topWeight, unit: unit, includeUnit: false)) × \(time)"
        }
    }
}

#Preview {
    NavigationStack {
        PersonalRecordsScreen()
    }
    .preferredColorScheme(.dark)
}
