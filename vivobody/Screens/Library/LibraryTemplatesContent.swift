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

            ForEach(displayed) { template in
                Button {
                    templateEditorTarget = .edit(template)
                } label: {
                    TemplateCard(template: template)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Surface.edge)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.gutter, bottom: 0, trailing: Space.gutter))
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
    /// same entry point Today exposes. AppState swaps in the active
    /// session; the app shell surfaces the live workout.
    private func startWorkout(from template: WorkoutTemplate) {
        Haptics.soft()
        appState.workout.startWorkoutFromTemplate(template)
    }
}

// MARK: - Template row

/// A saved plan as a full-width hairline row — no card. Two tiers,
/// mirroring the Exercises segment: a template scheduled for today
/// reads prominent (brighter name, larger numeral, taller row), the
/// rest stay quiet. Left side: name, a sentence-case meta line
/// ("4 exercises · Chest · Back"), and — when scheduled — a seven-
/// letter weekday rail with the pinned days lit (today's in orange).
/// Right side: the total planned-set count as a monospaced numeral,
/// the row's instrument anchor. The List that hosts it draws the
/// separators.
struct TemplateCard: View {
    let template: WorkoutTemplate

    private var isToday: Bool {
        template.isScheduled(on: Calendar.current.component(.weekday, from: Date()))
    }

    var body: some View {
        HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(Typography.title)
                    .foregroundStyle(isToday ? Ink.primary : Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(isToday ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if template.isScheduled {
                    WeekdayRail(
                        scheduled: Set(template.scheduledWeekdays),
                        today: Calendar.current.component(.weekday, from: Date())
                    )
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: Space.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(template.totalPlannedSets)")
                    .font(isToday ? Typography.statValue : Typography.metricInline)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(template.totalPlannedSets == 1 ? "set" : "sets")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .layoutPriority(1)
        }
        .frame(minHeight: isToday ? 72 : Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let count = template.orderedExercises.count
        let exercises = count == 1 ? "1 exercise" : "\(count) exercises"
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        return groups.isEmpty ? exercises : "\(exercises) · \(groups)"
    }
}

// MARK: - Weekday rail

/// Seven single-letter weekdays in the calendar's display order —
/// the "quiet calendar" treatment of a template's schedule. Pinned
/// days read in primary ink, today's pinned day in orange, the rest
/// stay faint. Replaces the old "Wed · Fri · Sat" prose line.
private struct WeekdayRail: View {
    let scheduled: Set<Int>
    let today: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(WeekdayLabels.ordered(), id: \.self) { day in
                Text(WeekdayLabels.veryShort(day))
                    .font(Typography.metricMicro)
                    .foregroundStyle(color(for: day))
                    .frame(minWidth: 13)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scheduled \(WeekdayLabels.summary(Array(scheduled)))")
    }

    private func color(for day: Int) -> Color {
        guard scheduled.contains(day) else { return Ink.quaternary }
        return day == today ? Tint.primary : Ink.primary
    }
}
