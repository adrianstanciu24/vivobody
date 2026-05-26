//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, most-recent first. Reads
//  from SwiftData via @Query so it stays in sync as new sessions
//  land. Tapping a row pushes a detail view that reuses
//  WorkoutSummaryCard — the same "receipt" the user saw at the end
//  of the workout, now as a permanent record.
//

import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Bindable var appState: AppState

    /// Every completed (archived) session. SwiftData orders results
    /// by completedAt descending, so the most-recent workout sits
    /// at the top. Mid-flight sessions are still un-inserted and
    /// therefore invisible to this query.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    private var sessions: [WorkoutSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                GlassSphere(size: 132, tint: Tint.primary)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 56, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Tint.primary, .white.opacity(0.30))
                    .symbolEffect(.breathe.pulse, options: .repeating)
            }
            .primaryGlow(Tint.primary, radius: 32, y: 0)

            VStack(spacing: 6) {
                Text("No workouts yet")
                    .sectionHeadingStyle()
                Text("Finish your first session and it lands here.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailScreen(session: session)
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Row

/// One row in the history list — a compact summary of a single
/// archived session. Date headline, duration / volume / sets strip,
/// and the muscle-group tags that day touched.
private struct SessionRow: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    private let completedGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateLine)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(timeLine)
                    .font(Typography.metricUnit)
                    .foregroundStyle(.white.opacity(0.50))
            }

            HStack(spacing: 0) {
                stat(value: "\(Int(session.duration / 60))", unit: "min", label: "Time")
                statDivider
                stat(value: volumeLabel(session.totalVolume), unit: unit.symbol, label: "Volume")
                statDivider
                stat(value: "\(session.totalSets)", unit: nil, label: "Sets")
            }

            if !muscleGroupTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(muscleGroupTags, id: \.self) { group in
                        Text(group.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(group.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(group.accent.opacity(0.14))
                            )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - Pieces

    private func stat(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            Text(label)
                .sectionLabelStyle(0.50)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Derived

    /// Distinct muscle groups touched by this session, in plan order.
    private var muscleGroupTags: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var ordered: [MuscleGroup] = []
        for exercise in session.orderedExercises {
            if seen.insert(exercise.group).inserted {
                ordered.append(exercise.group)
            }
        }
        return ordered
    }

    private var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return Self.relativeDateFormatter.string(from: date)
    }

    private var timeLine: String {
        let date = session.completedAt ?? session.startedAt
        return Self.timeFormatter.string(from: date)
    }

    private func volumeLabel(_ value: Double) -> String {
        WeightFormatter.volumeValue(value, unit: unit)
    }

    private static let relativeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d"
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

}

// MARK: - Detail

/// Pushed when the user taps a history row. Reuses WorkoutSummaryCard
/// — the same end-of-workout receipt, just looking at the past instead
/// of the present. The card reads the session's totals/exercises
/// directly, so no transformation is needed.
private struct SessionDetailScreen: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            WorkoutSummaryCard(session: session, isHistorical: true)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
