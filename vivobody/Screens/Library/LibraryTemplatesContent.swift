//
//  LibraryTemplatesContent.swift
//  vivobody
//
//  Templates segment content and template card row for the
//  Library screen. Extracted from LibraryScreen.swift for file
//  size management.
//

import VivoKit
import SwiftUI
import SwiftData

// MARK: - Templates content

/// Templates segment — list of saved workout plans. Tap a row to
/// edit it in the modal builder; swipe-right (or long-press) to
/// start a workout from it; swipe-left to delete. Empty state offers
/// an inline create button. Inherits search text from the parent and
/// filters by name.
struct LibraryTemplatesContent: View {
    @Bindable var appState: AppState
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var templateEditorTarget: TemplateEditorTarget?

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder)])
    private var templates: [WorkoutTemplate]

    @State private var deletingTemplate: WorkoutTemplate? = nil
    @State private var saveError: SaveErrorBox? = nil

    private var filtered: [WorkoutTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return templates }
        return templates.filter { $0.name.lowercased().contains(trimmed) }
    }

    /// Display order: anything scheduled for today floats to the top
    /// (the list's implicit "what's next" answer), the rest keep the
    /// user's manual sortOrder. Both partitions are stable.
    private var displayed: [WorkoutTemplate] {
        let today = Calendar.current.component(.weekday, from: Date())
        let base = filtered
        return base.filter { $0.isScheduled(on: today) }
            + base.filter { !$0.isScheduled(on: today) }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    emptyState
                }
            } else if filtered.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    noMatchesState
                }
            } else {
                list
            }
        }
        .alert(
            "Delete this template?",
            isPresented: deleteAlertBinding,
            presenting: deletingTemplate
        ) { template in
            Button("Delete", role: .destructive) {
                deleteTemplate(template)
            }
            Button("Cancel", role: .cancel) { }
        } message: { template in
            Text("\(template.name) · \(template.orderedExercises.count) exercises. This can't be undone.")
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - List

    private var list: some View {
        List {
            // First scrolling row — the segment moves up with the
            // content on scroll, so the large title collapses cleanly.
            SegmentedControl(selection: $segment)
                .accessibilityLabel("Library segment")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Space.sm, leading: Space.gutter, bottom: Space.lg, trailing: Space.gutter))

            let today = Calendar.current.component(.weekday, from: Date())
            ForEach(displayed) { template in
                let isToday = template.isScheduled(on: today)
                TemplateCard(
                    template: template,
                    onOpen: { templateEditorTarget = .edit(template) },
                    onStart: isToday ? { startWorkout(from: template) } : nil
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(isToday ? .hidden : .visible)
                .listRowSeparatorTint(Surface.edge)
                // The card tier pulls its background out toward the
                // screen edge (inset + internal padding == gutter) so
                // its text stays column-aligned with the quiet rows.
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: isToday ? Space.sm : Space.gutter,
                    bottom: isToday ? Space.md : 0,
                    trailing: isToday ? Space.sm : Space.gutter
                ))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        startWorkout(from: template)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(Tint.inProgress)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    // Force red: the app's global lime .tint would
                    // otherwise override the destructive role's color.
                    .tint(.red)
                }
                .contextMenu {
                    Button {
                        startWorkout(from: template)
                    } label: {
                        Label("Start workout", systemImage: "play.fill")
                    }
                    Button {
                        templateEditorTarget = .edit(template)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Empty states

    /// Type-forward empty state — a quiet heading, one line of
    /// guidance, and the single lime action. No ghost, no card.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No templates yet", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Build a reusable workout — pick exercises, set target reps and weight. Start any time from here.")
        } actions: {
            Button {
                templateEditorTarget = .new(sortOrder: templates.count)
                Haptics.soft()
            } label: {
                Text("Create Template")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var noMatchesState: some View {
        ContentUnavailableView.search
    }

    // MARK: - Plumbing

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        let id = template.id
        modelContext.delete(template)
        do {
            try modelContext.saveOrRollback()
            for (i, t) in templates.enumerated() {
                t.sortOrder = i
            }
            try modelContext.saveOrRollback()
            SpotlightIndexer.removeTemplate(id: id)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
        deletingTemplate = nil
    }

    /// Start a workout from a template without leaving Library — the
    /// same entry point Today exposes, with the same crescendo so
    /// starting a session sounds identical from either surface.
    private func startWorkout(from template: WorkoutTemplate) {
        Haptics.crescendo()
        appState.workout.startWorkoutFromTemplate(template)
    }
}

// MARK: - Template row

/// A saved plan in the Library list. Two tiers with real hierarchy:
/// a template scheduled for today lifts onto a card surface with a
/// "TODAY" eyebrow and an inline Start action; the rest stay quiet
/// full-width hairline rows (the List draws their separators). Every
/// row shares one anatomy: name, an exercise-name preview line, a
/// workload line (set pips grouped per exercise beside the set count
/// as a tabular numeral), and — when pinned — the scheduled days as
/// quiet text with today's day brightened.
struct TemplateCard: View {
    let template: WorkoutTemplate
    let onOpen: () -> Void
    var onStart: (() -> Void)? = nil

    private var today: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    private var isToday: Bool {
        template.isScheduled(on: today)
    }

    var body: some View {
        Group {
            if isToday {
                rowContent
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentCard()
            } else {
                rowContent
                    .padding(.vertical, Space.md)
                    .frame(minHeight: Space.rowMin)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Open-editor and Start are SIBLING buttons, not nested — a
    /// button inside another button's label gets flattened out of
    /// the accessibility tree and loses its tap target. The open
    /// button stretches to fill everything the Start pill doesn't.
    private var rowContent: some View {
        HStack(alignment: .center, spacing: Space.md) {
            Button(action: onOpen) {
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isToday, onStart != nil {
                startButton
            }
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isToday {
                Text("TODAY")
                    .font(Typography.micro)
                    .tracking(1.2)
                    .foregroundStyle(Tint.primary)
                    .padding(.bottom, 1)
            }
            Text(template.name)
                .font(Typography.sectionHeading)
                .foregroundStyle(isToday ? Ink.primary : Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !exercisePreview.isEmpty {
                Text(exercisePreview)
                    .font(Typography.caption)
                    .foregroundStyle(isToday ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
            }
            workloadLine
                .padding(.top, Space.sm)
            if template.isScheduled {
                scheduleText
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .padding(.top, Space.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// First three exercise names — the row's identity. Template
    /// names are abstract ("Lower B"); the lifts inside are not.
    private var exercisePreview: String {
        let names = template.orderedExercises.map(\.name)
        guard !names.isEmpty else { return "" }
        var preview = names.prefix(3).joined(separator: " · ")
        if names.count > 3 {
            preview += "  +\(names.count - 3)"
        }
        return preview
    }

    private var workloadLine: some View {
        HStack(alignment: .center, spacing: Space.sm + 2) {
            SetPipStrip(
                groups: template.orderedExercises.map(\.effectiveSetCount).filter { $0 > 0 },
                tint: isToday ? Ink.tertiary : Ink.quaternary
            )
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(template.totalPlannedSets)")
                    .font(Typography.metricInline)
                    .foregroundStyle(isToday ? Ink.primary : Ink.tertiary)
                Text(template.totalPlannedSets == 1 ? "set" : "sets")
                    .font(Typography.micro)
                    .foregroundStyle(Ink.quaternary)
            }
        }
    }

    /// Pinned days as quiet inline text ("Mon · Thu"). Today's day —
    /// only ever present on the card tier — reads brighter, not
    /// accented: the eyebrow and Start button own the orange budget.
    private var scheduleText: Text {
        let scheduled = Set(template.scheduledWeekdays)
        let days = WeekdayLabels.ordered().filter(scheduled.contains)
        var result = Text(verbatim: "")
        for (i, day) in days.enumerated() {
            var token = Text(WeekdayLabels.short(day))
            if day == today {
                token = token.foregroundStyle(Ink.primary).fontWeight(.semibold)
            }
            result = i == 0 ? token : Text("\(result) · \(token)")
        }
        return result
    }

    private var startButton: some View {
        Button {
            onStart?()
        } label: {
            Text("Start")
                .font(Typography.sectionLabel.weight(.semibold))
                .foregroundStyle(Tint.onAccent)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
        }
        .buttonStyle(.borderless)
        .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.primary)
        .accessibilityLabel("Start \(template.name)")
    }
}

// MARK: - Set-pip strip

/// Tally-style workload texture: one pip per planned set, grouped
/// per exercise, so each row carries a physical fingerprint of its
/// plan. Decorative — capped so outlier templates can't blow the row
/// width; the numeral beside it carries the exact count.
private struct SetPipStrip: View {
    let groups: [Int]
    let tint: Color

    private static let pipCap = 24

    private var cappedGroups: [Int] {
        var remaining = Self.pipCap
        var result: [Int] = []
        for count in groups {
            guard remaining > 0 else { break }
            let take = min(count, remaining)
            result.append(take)
            remaining -= take
        }
        return result
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(Array(cappedGroups.enumerated()), id: \.offset) { _, count in
                HStack(spacing: 2.5) {
                    ForEach(0..<count, id: \.self) { _ in
                        Capsule()
                            .fill(tint)
                            .frame(width: 3, height: 9)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
