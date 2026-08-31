//
//  StartWorkoutSheet.swift
//  vivobody
//
//  The single chooser for beginning a workout from Today. The pinned
//  Start Workout action always presents it, keeping the body-model hero
//  free of competing controls.
//
//  One prominent action reflects the most relevant start path: today's
//  scheduled plan first, otherwise Repeat Last, otherwise Start Fresh.
//  Fresh, repeat, and remaining saved templates sit below as one neutral
//  family. The featured scheduled template is never listed twice.
//
//  The sheet never starts the workout directly: it reports the chosen
//  intent to the caller and dismisses itself. TodayScreen runs the
//  intent in the sheet's onDismiss, so the focused ActiveWorkoutScreen
//  only presents after this sheet is fully gone — avoiding a
//  sheet-over-sheet presentation conflict.
//

import SwiftData
import SwiftUI
import VivoKit

/// What the user picked in the start sheet. The caller maps these to
/// the matching AppState lifecycle calls.
enum StartIntent {
    case repeatLast
    case fresh
    case template(WorkoutTemplate)
}

struct StartWorkoutSheet: View {
    /// The most recent archived session, if any — drives the Repeat
    /// CTA and its plan summary.
    let lastSession: WorkoutSession?

    /// Saved templates, pre-sorted most-recently-used first.
    let templates: [WorkoutTemplate]

    /// Today's schedule-driven recommendation, when one is due. It becomes
    /// the sheet's prominent action and is removed from the alternate list.
    let scheduledTemplate: WorkoutTemplate?

    /// Reports the chosen start path back to the caller. The caller is
    /// expected to defer the actual start until this sheet dismisses.
    let onSelect: (StartIntent) -> Void

    init(
        lastSession: WorkoutSession?,
        templates: [WorkoutTemplate],
        scheduledTemplate: WorkoutTemplate? = nil,
        onSelect: @escaping (StartIntent) -> Void
    ) {
        self.lastSession = lastSession
        self.templates = templates
        self.scheduledTemplate = scheduledTemplate
        self.onSelect = onSelect
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        if let scheduledTemplate {
                            scheduledSection(scheduledTemplate)
                        } else if lastSession != nil {
                            repeatSection
                        }
                        startFromSection
                    }
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxl)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .tint(Tint.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    /// The plan due today is the sheet's one visual anchor. "Plan" is the
    /// user's concept; the authored template name remains visible underneath.
    private func scheduledSection(_ template: WorkoutTemplate) -> some View {
        PrimaryActionButton(
            title: "Start Today's Plan",
            subtitle: template.name,
            icon: nil,
            inputLabels: ["Start Today's Plan", "Start Plan", "Start Workout"],
            sound: .commit
        ) {
            select(.template(template))
        }
        .accessibilityLabel("Start today's plan, \(template.name)")
        .accessibilityHint("Starts the workout scheduled for today")
        .accessibilityIdentifier("scheduledWorkoutStartButton")
    }

    /// The single prominent action: repeat the most recent workout.
    /// No "last time" header or plan summary — the CTA carries the
    /// meaning on its own.
    private var repeatSection: some View {
        PrimaryActionButton(
            title: "Repeat Last Workout",
            inputLabels: ["Repeat Last Workout", "Repeat", "Repeat Last"],
            sound: .commit
        ) {
            select(.repeatLast)
        }
        .accessibilityHint("Starts a workout matching your last session")
    }

    /// Every remaining way to start, as one family of tiles. Without a
    /// scheduled plan or history, Start Fresh promotes itself so the sheet
    /// still has exactly one visual anchor.
    private var startFromSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: startFromTitle)

            GlassEffectContainer(spacing: Space.md) {
                VStack(spacing: Space.md) {
                    if scheduledTemplate != nil, lastSession != nil {
                        startTile(
                            title: "Repeat Last Workout",
                            icon: "arrow.counterclockwise",
                            accessibility: "Repeat last workout"
                        ) {
                            select(.repeatLast)
                        }
                        .accessibilityHint("Starts a workout matching your last session")
                    }

                    if lastSession == nil, scheduledTemplate == nil {
                        PrimaryActionButton(
                            title: "Start Fresh",
                            icon: "plus",
                            inputLabels: ["Start Fresh", "Fresh", "New Workout"],
                            sound: .commit
                        ) {
                            select(.fresh)
                        }
                        .accessibilityHint("Opens the exercise picker for a fresh workout")
                    } else {
                        startTile(
                            title: "Start Fresh",
                            icon: "plus",
                            accessibility: "Start Fresh"
                        ) {
                            select(.fresh)
                        }
                        .accessibilityHint("Opens the exercise picker for a fresh workout")
                        .accessibilityInputLabels([Text("Start Fresh"), Text("Fresh"), Text("New Workout")])
                    }

                    ForEach(alternateTemplates, id: \.id) { template in
                        startTile(
                            title: template.name,
                            subtitle: templateSubtitle(template),
                            icon: "arrow.right",
                            accessibility: "Start \(template.name)",
                            filled: true
                        ) {
                            select(.template(template))
                        }
                        .accessibilityHint("Starts this workout now")
                    }
                }
            }
        }
    }

    /// The shared tile shell for Start Fresh and every template.
    /// Tapping a tile starts that workout immediately, so the trailing
    /// glyph is an action affordance (plus / arrow), never a navigation
    /// chevron.
    ///
    /// Two surfaces, so the tiers read apart at a glance: Start Fresh
    /// is a neutral outlined glass control (it *looks* empty — fitting
    /// a blank canvas), while saved templates sit on a filled glass
    /// card (a solid piece of material — they already hold a plan). No
    /// second colour; the distinction is fill vs. outline.
    private func startTile(
        title: String,
        subtitle: String? = nil,
        icon: String,
        accessibility: String,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.soft(sound: .commit)
            action()
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: Space.sm)

                Image(systemName: icon)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, Space.gutter)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .modifier(StartTileSurface(filled: filled))
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    // MARK: - Helpers

    private var startFromTitle: String {
        if scheduledTemplate != nil { return "Other options" }
        return lastSession == nil ? "Start from" : "Or start from"
    }

    private var alternateTemplates: [WorkoutTemplate] {
        guard let scheduledTemplate else { return templates }
        return templates.filter { $0.id != scheduledTemplate.id }
    }

    /// Reports the pick to the caller, then dismisses. The caller
    /// performs the actual start once this sheet is gone.
    private func select(_ intent: StartIntent) {
        onSelect(intent)
        dismiss()
    }

    private func templateSubtitle(_ template: WorkoutTemplate) -> String {
        let count = template.orderedExercises.count
        let base = "\(count) ex · \(template.totalPlannedSets) sets"
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        return groups.isEmpty ? base : "\(base) · \(groups)"
    }
}

/// The two start-tile surfaces. `filled` templates ride the standard
/// glass card; the hollow Start Fresh uses neutral interactive glass
/// with a fine outline so the empty start and the saved plans never
/// blur together.
private struct StartTileSurface: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        if filled {
            content.glassCard(cornerRadius: Radius.card, interactive: true)
        } else {
            content
                .glassTinted(interactive: true, in: shape)
                .overlay {
                    shape.stroke(Surface.edge, lineWidth: 1)
                }
                .containerShape(shape)
                .contentShape(shape)
        }
    }
}

private func sampleTemplates() -> [WorkoutTemplate] {
    let three = WorkoutTemplate(name: "Test 3", exercises: [
        TemplateExercise(name: "Barbell Bench Press", group: .chest, plannedWeight: 135, sortOrder: 0),
        TemplateExercise(name: "Barbell Bent-Over Row", group: .back, plannedWeight: 95, sortOrder: 1),
        TemplateExercise(name: "Dumbbell Shoulder Press", group: .shoulders, plannedWeight: 65, sortOrder: 2),
    ])
    let two = WorkoutTemplate(name: "Test", exercises: [
        TemplateExercise(name: "Incline Dumbbell Bench Press", group: .chest, plannedWeight: 95, sortOrder: 0),
        TemplateExercise(name: "Lat Pulldown", group: .back, plannedWeight: 110, sortOrder: 1),
    ])
    return [three, two]
}

#Preview("Repeat + templates") {
    StartWorkoutSheet(lastSession: WorkoutSession(), templates: sampleTemplates()) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("No last session") {
    StartWorkoutSheet(lastSession: nil, templates: sampleTemplates()) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Today's plan") {
    let templates = sampleTemplates()
    StartWorkoutSheet(
        lastSession: WorkoutSession(),
        templates: templates,
        scheduledTemplate: templates.first
    ) { _ in }
        .preferredColorScheme(.dark)
}
