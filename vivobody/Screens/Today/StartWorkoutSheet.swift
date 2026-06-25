//
//  StartWorkoutSheet.swift
//  vivobody
//
//  The single entry point for beginning a workout. Presented from the
//  pinned "+ Start" pill on the Today screen so the 3D body model can
//  own the whole hero without start buttons crowding it.
//
//  Lists every start path in priority order:
//    1. Repeat last workout — the most common case, so it's the
//       prominent orange CTA at the top (only when there's a session
//       to repeat).
//    2. Start from — Start fresh and every saved template share one
//       outlined-tile shell so the start paths read as a single
//       family of buttons rather than buttons-then-a-nav-list. When
//       there's no session to repeat, Start fresh promotes itself to
//       the prominent orange CTA so the sheet always has one anchor.
//       Templates are most-recently-used first (the caller pre-sorts).
//
//  The sheet never starts the workout directly: it reports the chosen
//  intent to the caller and dismisses itself. TodayScreen runs the
//  intent in the sheet's onDismiss, so the focused ActiveWorkoutScreen
//  only presents after this sheet is fully gone — avoiding a
//  sheet-over-sheet presentation conflict.
//

import SwiftUI
import SwiftData

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

    /// Reports the chosen start path back to the caller. The caller is
    /// expected to defer the actual start until this sheet dismisses.
    let onSelect: (StartIntent) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        if lastSession != nil {
                            repeatSection
                        }
                        startFromSection
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxl)
                }
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

    /// The single prominent action: repeat the most recent workout.
    /// No "last time" header or plan summary — the CTA carries the
    /// meaning on its own.
    private var repeatSection: some View {
        PrimaryActionButton(title: "Repeat Last Workout") {
            select(.repeatLast)
        }
    }

    /// Every other way to start, as one family of tiles. Start Fresh
    /// leads; the saved templates follow. When there's no session to
    /// repeat, Start Fresh promotes itself to the prominent orange CTA
    /// so the sheet always has exactly one anchor.
    private var startFromSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: lastSession == nil ? "Start from" : "Or start from")

            GlassEffectContainer(spacing: Space.md) {
                VStack(spacing: Space.md) {
                    if lastSession == nil {
                        PrimaryActionButton(title: "Start Fresh", icon: "plus") {
                            select(.fresh)
                        }
                    } else {
                        startTile(
                            title: "Start Fresh",
                            icon: "plus",
                            accessibility: "Start a fresh workout"
                        ) {
                            select(.fresh)
                        }
                    }

                    ForEach(templates, id: \.id) { template in
                        startTile(
                            title: template.name,
                            subtitle: templateSubtitle(template),
                            icon: "arrow.right",
                            accessibility: "Start \(template.name)",
                            filled: true
                        ) {
                            select(.template(template))
                        }
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
    /// is a hollow outline (it *looks* empty — fitting a blank canvas),
    /// while saved templates sit on a filled glass card (a solid piece
    /// of material — they already hold a plan). No second colour; the
    /// distinction is fill vs. outline.
    private func startTile(
        title: String,
        subtitle: String? = nil,
        icon: String,
        accessibility: String,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                            .lineLimit(1)
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
/// glass card; the hollow Start Fresh gets a stroke-only outline so
/// the empty start and the saved plans never blur together.
private struct StartTileSurface: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        if filled {
            content.glassCard(cornerRadius: Radius.card, interactive: true)
        } else {
            content.overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Surface.edge, lineWidth: 1)
            )
        }
    }
}

private func sampleTemplates() -> [WorkoutTemplate] {
    let three = WorkoutTemplate(name: "Test 3", exercises: [
        TemplateExercise(name: "Bench Press", group: .chest, plannedWeight: 135, sortOrder: 0),
        TemplateExercise(name: "Barbell Row", group: .back, plannedWeight: 95, sortOrder: 1),
        TemplateExercise(name: "Overhead Press", group: .shoulders, plannedWeight: 65, sortOrder: 2),
    ])
    let two = WorkoutTemplate(name: "Test", exercises: [
        TemplateExercise(name: "Incline Press", group: .chest, plannedWeight: 95, sortOrder: 0),
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
