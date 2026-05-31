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
//       prominent lime CTA at the top (only when there's a session to
//       repeat).
//    2. Start fresh — a blank canvas.
//    3. Templates — one row per saved template, most-recently-used
//       first (the caller pre-sorts).
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
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        if let lastSession {
                            repeatSection(lastSession)
                        }
                        freshSection
                        if !templates.isEmpty {
                            templatesSection
                        }
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
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
    }

    // MARK: - Sections

    private func repeatSection(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Last time")

            Text(planSummary(for: session))
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)

            PrimaryActionButton(title: "Repeat Last Workout") {
                select(.repeatLast)
            }
        }
    }

    /// Outlined sibling to the Repeat CTA — a clean, empty start. When
    /// there's no last session this is the only filled option, so it
    /// promotes itself to a primary lime button instead.
    private var freshSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: lastSession == nil ? "Today's workout" : "Or start from")

            if lastSession == nil {
                PrimaryActionButton(title: "Start Workout", icon: "plus") {
                    select(.fresh)
                }
            } else {
                freshButton
            }
        }
    }

    private var freshButton: some View {
        Button {
            select(.fresh)
        } label: {
            HStack(spacing: Space.sm) {
                Text("Start Fresh")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Surface.edge, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a fresh workout")
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Templates")

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    if index > 0 { SectionDivider() }
                    templateRow(template)
                }
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            Haptics.soft()
            select(.template(template))
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    Text(templateSubtitle(template))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: Space.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.quaternary)
            }
            .frame(minHeight: Space.rowMin)
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(template.name)")
    }

    // MARK: - Helpers

    /// Reports the pick to the caller, then dismisses. The caller
    /// performs the actual start once this sheet is gone.
    private func select(_ intent: StartIntent) {
        onSelect(intent)
        dismiss()
    }

    private func planSummary(for session: WorkoutSession) -> String {
        let exercises = session.orderedExercises
        guard !exercises.isEmpty else {
            return "A blank canvas — add exercises as you go."
        }
        let groups = Set(exercises.map(\.group))
        let groupNames = groups.map(\.displayName).joined(separator: " · ")
        return "\(exercises.count) exercises  ·  \(groupNames)"
    }

    private func templateSubtitle(_ template: WorkoutTemplate) -> String {
        let count = template.orderedExercises.count
        let base = "\(count) ex · \(template.totalPlannedSets) sets"
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        return groups.isEmpty ? base : "\(base) · \(groups)"
    }
}
