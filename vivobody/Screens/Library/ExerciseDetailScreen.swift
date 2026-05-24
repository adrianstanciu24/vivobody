//
//  ExerciseDetailScreen.swift
//  vivobody
//
//  Drill-down view for an ExerciseCatalogItem. Reached by tapping
//  a row in the ExercisePickerSheet — replaces the previous "tap =
//  immediate pick" behavior with "tap = explore, then commit via
//  CTA at the bottom." Long-press on the picker row preserves the
//  quick Edit / Delete context menu.
//
//  Surfaces (when data exists):
//    • Hero    — muscle group accent + exercise name + metadata
//                chips (equipment / pattern / mechanic)
//    • Stats   — Last (top set + relative date), Best (all-time top
//                weight), Count (sessions that included this lift)
//    • Chart   — SwiftUI Charts line with PR dots + time-range chips
//    • Cues    — Catalog-level form notes (persistent across all
//                sessions), tap to edit via NotesEditorSheet
//    • Recents — Last 5 sessions, top set + date + PR flag
//    • Defaults— The catalog item's starting weight × reps
//    • CTA     — "+ Add to Workout" pinned to the bottom safe area
//
//  Empty-state behavior: when the user has never logged this
//  exercise, the stats row shows em-dashes, the chart and recents
//  sections are hidden, and the rest of the screen still functions
//  (notes, defaults, CTA, edit/delete).
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    /// The catalog item this screen is exploring. Held as a let —
    /// SwiftData @Model observation handles updates when the editor
    /// sheet mutates the underlying record.
    let item: ExerciseCatalogItem

    /// Bundles the picker's `onPick(item)` + its own `dismiss()` into
    /// a single closure. Nil hides the bottom CTA entirely — useful
    /// when the detail is reached from a non-picking context (future
    /// surfaces like a standalone "Library" tab).
    let onPickAndDismiss: ((ExerciseCatalogItem) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// All archived sessions — drives progress chart + last-used +
    /// total-count + recent table. Same filter as the picker; live
    /// in-flight sessions never contribute.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var editorTarget: CatalogEditorTarget?
    @State private var isConfirmingDelete: Bool = false
    @State private var isEditingNotes: Bool = false
    @State private var range: TimeRange = .all

    /// Chart time-range chips. Same enum-shape as
    /// ExerciseProgressDetail.TimeRange — kept private to this screen
    /// because the two screens have separate lifecycles (and the
    /// shared shape isn't reused in a meaningful enough way yet to
    /// justify hoisting it out).
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:    return "1M"
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .all:         return "All"
            }
        }
        var cutoff: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: Date())
            case .all:         return nil
            }
        }
    }

    private let prColor = Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero
                statsRow
                if hasHistory {
                    chartSection
                }
                formCuesSection
                if hasHistory {
                    recentSessionsSection
                }
                defaultsSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editorTarget = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("More options")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if onPickAndDismiss != nil {
                addToWorkoutCTA
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
        .sheet(isPresented: $isEditingNotes) {
            NotesEditorSheet(
                title: "\(item.name) Cues",
                placeholder: "Form cues, plate setup, what to remember…",
                initialValue: item.notes,
                onSave: { newNotes in
                    item.notes = newNotes
                    try? modelContext.save()
                }
            )
        }
        .alert(
            "Delete \"\(item.name)\"?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                deleteAndDismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes the exercise from your catalog. Templates and history that already reference it stay intact.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Muscle group label tinted with the group accent — same
            // pattern used on every other exercise surface in the app
            // (active card, summary row, picker subtitle).
            HStack(spacing: 8) {
                Circle().fill(item.group.accent).frame(width: 8, height: 8)
                Text(item.group.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(item.group.accent)
            }

            Text(item.name)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Metadata chip strip — equipment + pattern (when compound)
            // or equipment + "Isolation" (when isolation). Always
            // shows mechanic last so the rhythm is consistent.
            HStack(spacing: 8) {
                metadataChip(symbol: item.equipment.symbol, label: item.equipment.displayName)
                if item.mechanic == .compound, let pattern = item.pattern {
                    metadataChip(symbol: nil, label: pattern.displayName)
                }
                metadataChip(symbol: nil, label: item.mechanic.displayName)
            }
        }
    }

    private func metadataChip(symbol: String?, label: String) -> some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.80))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCard(
                label: "LAST",
                value: lastValueString,
                detail: lastDetailString
            )
            statDivider
            statCard(
                label: "BEST",
                value: bestValueString,
                detail: bestDetailString
            )
            statDivider
            statCard(
                label: "TIMES",
                value: countString,
                detail: countDetailString
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func statCard(label: String, value: String, detail: String?) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.50))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            } else {
                // Reserves a baseline so columns with detail and
                // columns without it stay vertically aligned.
                Text(" ")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 54)
    }

    // MARK: - Chart section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRESS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            chart

            HStack(spacing: 8) {
                ForEach(TimeRange.allCases) { r in
                    rangeChip(r)
                }
            }
        }
    }

    private var chart: some View {
        let visible = visiblePoints
        return Chart {
            ForEach(visible) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", chartValue(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.white.opacity(0.85))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", chartValue(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if point.isWeightPR {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", chartValue(for: point))
                    )
                    .symbol(.circle)
                    .symbolSize(60)
                    .foregroundStyle(prColor)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .frame(height: 200)
    }

    private func rangeChip(_ r: TimeRange) -> some View {
        let isSelected = r == range
        return Button {
            Haptics.selection()
            range = r
        } label: {
            Text(r.label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Form cues

    private var formCuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FORM CUES")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                if !item.notes.isEmpty {
                    Button {
                        Haptics.soft()
                        isEditingNotes = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Edit")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit form cues")
                }
            }

            cuesContent
        }
    }

    @ViewBuilder
    private var cuesContent: some View {
        if item.notes.isEmpty {
            Button {
                Haptics.soft()
                isEditingNotes = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add form cues")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                )
            }
            .buttonStyle(.plain)
        } else {
            Text(item.notes)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Recent sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT SESSIONS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            let rows = recentRows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    recentRow(row)
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func recentRow(_ row: RecentSessionRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: row.date))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                Text(RelativeDate.short(row.date))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .frame(width: 90, alignment: .leading)

            Text("\(WeightFormatter.string(row.topWeight, unit: unit)) × \(row.topReps)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Text("× \(row.setCount)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

            if row.isPR {
                Text("PR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(prColor))
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEFAULTS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            HStack(spacing: 16) {
                defaultStat(label: "WEIGHT", value: WeightFormatter.string(item.defaultWeight, unit: unit))
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 32)
                defaultStat(label: "REPS", value: "\(item.defaultReps)")
                Spacer()
                Text("Used when first picked")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func defaultStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - CTA

    private var addToWorkoutCTA: some View {
        Button {
            Haptics.thunk()
            onPickAndDismiss?(item)
        } label: {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add to Workout")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .padding(.top, 12)
        .background(
            // Slight backdrop fade keeps the CTA legible over
            // whatever's behind it when the scroll content reaches
            // the bottom — and gives the pinned bar a sense of
            // floating above the page.
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Derived

    /// Captures one row in the Recent Sessions table.
    private struct RecentSessionRow {
        let date: Date
        let topWeight: Double
        let topReps: Int
        let setCount: Int
        let isPR: Bool
    }

    /// Lowercased name lookup key matching the convention used in
    /// `lastInstanceByExercise()` and `progressByExercise`.
    private var nameKey: String { item.name.lowercased() }

    /// All progress points for this exercise across history. Nil
    /// when the user has fewer than 2 sessions (matches the
    /// >=2 filter inside `progressByExercise`). The chart needs
    /// at least 2 points to be more than a dot.
    private var progress: ExerciseProgress? {
        completedSessions.progressByExercise.first { $0.name.lowercased() == nameKey }
    }

    /// Most-recent top set + relative date + PR flag. Nil when the
    /// user has never logged this exercise.
    private var lastInstance: LastExerciseInstance? {
        completedSessions.lastInstanceByExercise()[nameKey]
    }

    /// Number of archived sessions that include this exercise.
    private var sessionCount: Int {
        completedSessions.reduce(0) { acc, session in
            acc + (session.orderedExercises.contains(where: {
                $0.name.lowercased() == nameKey
                && $0.sets.contains(where: \.isCompleted)
            }) ? 1 : 0)
        }
    }

    /// True if there's any history at all (>=1 session). Distinct
    /// from `progress != nil` which requires >=2 sessions — the
    /// chart hides on 0 or 1 sessions, but the recent-sessions
    /// table can still surface a single instance.
    private var hasHistory: Bool { lastInstance != nil }

    /// Latest 5 sessions for this exercise (newest first), with
    /// top set + total completed-set count + PR flag computed.
    private var recentRows: [RecentSessionRow] {
        // Walk archive newest-first (already sorted that way via
        // the @Query order: .reverse), pick up to 5 sessions that
        // include this exercise.
        let allTimeBest = completedSessions
            .flatMap(\.orderedExercises)
            .filter { $0.name.lowercased() == nameKey }
            .flatMap { $0.sets.filter(\.isCompleted) }
            .map(\.weight)
            .max() ?? 0

        var rows: [RecentSessionRow] = []
        for session in completedSessions {
            guard let exercise = session.orderedExercises.first(where: {
                $0.name.lowercased() == nameKey
            }) else { continue }
            let completed = exercise.sets.filter(\.isCompleted)
            guard !completed.isEmpty else { continue }

            let top = completed.max { a, b in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            }!
            let date = session.completedAt ?? session.startedAt

            rows.append(RecentSessionRow(
                date: date,
                topWeight: top.weight,
                topReps: top.reps,
                setCount: completed.count,
                isPR: top.weight >= allTimeBest
            ))

            if rows.count >= 5 { break }
        }
        return rows
    }

    // MARK: - Display strings (stats row)

    /// "145 × 8" (in user's unit) when there's history; "—" otherwise.
    private var lastValueString: String {
        guard let last = lastInstance else { return "—" }
        return "\(WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false)) × \(last.topReps)"
    }

    private var lastDetailString: String? {
        guard let last = lastInstance else { return nil }
        return RelativeDate.short(last.sessionDate)
    }

    private var bestValueString: String {
        guard let prog = progress else {
            // Progress requires >=2 sessions. If we have 1, surface
            // that single top set as the "best" so the column isn't
            // empty when the user is just getting started.
            if let last = lastInstance {
                return WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false)
            }
            return "—"
        }
        return WeightFormatter.string(prog.bestWeight, unit: unit, includeUnit: false)
    }

    private var bestDetailString: String? {
        guard let prog = progress else {
            // For a one-session user the "best" IS today's session.
            guard let last = lastInstance else { return nil }
            return RelativeDate.short(last.sessionDate)
        }
        // Find when the all-time best was achieved.
        if let bestPoint = prog.points.first(where: { $0.topWeight == prog.bestWeight }) {
            return RelativeDate.short(bestPoint.date)
        }
        return nil
    }

    private var countString: String {
        sessionCount > 0 ? "\(sessionCount)" : "—"
    }

    private var countDetailString: String? {
        guard sessionCount > 0 else { return nil }
        return sessionCount == 1 ? "session" : "sessions"
    }

    // MARK: - Chart helpers

    /// Filter progress points by the selected time range. Empty array
    /// when the user has no progress (chart section is hidden in
    /// that case via `hasHistory`).
    private var visiblePoints: [ExerciseProgressPoint] {
        guard let prog = progress else { return [] }
        guard let cutoff = range.cutoff else { return prog.points }
        return prog.points.filter { $0.date >= cutoff }
    }

    /// Convert canonical-lb top weight to the display unit for the
    /// chart's y-axis. Same pattern used in ExerciseProgressDetail.
    private func chartValue(for point: ExerciseProgressPoint) -> Double {
        WeightFormatter.toDisplay(point.topWeight, unit: unit)
    }

    // MARK: - Mutations

    /// Remove the catalog item, save, then dismiss the screen — the
    /// picker's @Query will refresh and the row disappears. Templates
    /// and history are unaffected (they copy values at pick-time and
    /// never reference catalog items directly).
    private func deleteAndDismiss() {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.thunk()
        dismiss()
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
