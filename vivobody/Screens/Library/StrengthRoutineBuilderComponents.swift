//
//  StrengthRoutineBuilderComponents.swift
//  vivobody
//
//  Focused controls for the automatic strength-routine flow. Planning choices
//  stay compact and glanceable; draft review shows one day at a time with the
//  prescription and short catalog-backed selection reason on each row.
//

import SwiftUI
import VivoKit

struct StrengthRoutineChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Text(label)
                .font(Typography.sectionHeading)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .lineLimit(1)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
                .background {
                    if isSelected {
                        Color.clear
                            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Surface.cardTint)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .modifier(OptionalAccessibilityIdentifier(value: accessibilityIdentifier))
    }
}

struct StrengthRoutineDayChoice: Identifiable, Hashable {
    let id: Int
    let shortLabel: String
    let fullLabel: String
    var detail: String? = nil
}

struct StrengthRoutineDaySelector: View {
    let days: [StrengthRoutineDayChoice]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                ForEach(days) { day in
                    let selected = day.id == selection
                    Button {
                        selection = day.id
                        Haptics.selection()
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.shortLabel)
                                .font(Typography.headline)
                            if let detail = day.detail {
                                Text(detail)
                                    .font(Typography.micro)
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(selected ? Tint.onAccent : Ink.secondary)
                        .padding(.horizontal, Space.lg)
                        .frame(minWidth: 84, minHeight: Space.tapMin)
                        .background {
                            if selected {
                                Color.clear
                                    .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                            } else {
                                Capsule(style: .continuous)
                                    .fill(Surface.cardTint)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.fullLabel)
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("strengthRoutineDay\(day.id)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct StrengthRoutineSummaryCard: View {
    let days: Int
    let exercises: Int
    let minutes: Int
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("WEEK")
                    .font(Typography.micro)
                    .tracking(1.2)
                    .foregroundStyle(Tint.primary)
                Spacer(minLength: Space.md)
                Text(status)
                    .panelLegend()
            }

            StatStrip(
                stats: [
                    Stat(value: "\(days)", label: days == 1 ? "Day" : "Days"),
                    Stat(value: "\(exercises)", label: "Exercises"),
                    Stat(value: "\(minutes)", unit: "min", label: "Per day"),
                ],
                valueFont: Typography.statValueCompact
            )
        }
        .padding(Space.lg)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly routine. \(days) days, \(exercises) exercises, about \(minutes) minutes per day. \(status).")
    }
}

struct StrengthRoutineExerciseDisplay: Identifiable, Hashable {
    let id: String
    let day: String
    let position: Int
    let count: Int
    let name: String
    let prescription: String
    let reason: String
    let isIncluded: Bool
    let isLocked: Bool

    var accessibilityLabel: String {
        "\(day), exercise \(position) of \(count), \(name)"
    }

    var accessibilityValue: String {
        let lockState = isLocked ? "Locked." : "Unlocked."
        let swapState = isIncluded ? " Swap unavailable for an included exercise." : ""
        return "\(prescription). \(reason). \(lockState)\(swapState)"
    }
}

struct StrengthRoutineExerciseRow: View {
    let exercise: StrengthRoutineExerciseDisplay
    let onToggleLock: () -> Void
    let onSwap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                exerciseSummary

                Spacer(minLength: Space.sm)

                lockButton
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.md) {
                    reasonLabel
                    if !exercise.isIncluded {
                        swapButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: Space.sm) {
                    reasonLabel
                    if !exercise.isIncluded {
                        Spacer(minLength: Space.sm)
                        swapButton
                    }
                }
            }
        }
        .padding(Space.lg)
        .contentCard()
        .accessibilityElement(children: .contain)
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(exercise.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(exercise.prescription)
                .font(Typography.metricInline)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.accessibilityLabel)
        .accessibilityValue(exercise.accessibilityValue)
    }

    private var reasonLabel: some View {
        Label {
            Text(exercise.reason)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "scope")
                .foregroundStyle(Tint.primary)
        }
        .font(Typography.caption)
        .foregroundStyle(Ink.tertiary)
        .accessibilityHidden(true)
    }

    private var lockButton: some View {
        Button(action: onToggleLock) {
            Image(systemName: exercise.isLocked ? "lock.fill" : "lock.open")
                .font(Typography.headline)
                .foregroundStyle(exercise.isLocked ? Tint.primary : Ink.tertiary)
                .frame(width: Space.tapMin, height: Space.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exercise.isLocked ? "Unlock \(exercise.name)" : "Lock \(exercise.name)")
        .accessibilityValue(exercise.isLocked ? "Locked" : "Unlocked")
        .accessibilityIdentifier("strengthRoutineLock-\(exercise.id)")
    }

    private var swapButton: some View {
        Button(action: onSwap) {
            Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.md)
                .frame(minHeight: Space.tapMin)
                .contentChip()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap \(exercise.name)")
        .accessibilityIdentifier("strengthRoutineSwap-\(exercise.id)")
    }
}

struct StrengthRoutineGapStatus: View {
    let messages: [String]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .padding(.top, Space.sm)
            .padding(.bottom, Space.md)
        } label: {
            Label(summary, systemImage: messages.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(Typography.sectionHeading)
                .foregroundStyle(messages.isEmpty ? Tint.complete : Tint.inProgress)
                .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
        }
        .tint(Ink.tertiary)
        .accessibilityIdentifier("strengthRoutineGapStatus")
    }

    private var summary: String {
        "\(messages.count) plan \(messages.count == 1 ? "issue" : "issues")"
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let value: String?

    func body(content: Content) -> some View {
        if let value {
            content.accessibilityIdentifier(value)
        } else {
            content
        }
    }
}

#if DEBUG
    #Preview("Routine builder components") {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack {
                    StrengthRoutineChoiceChip(label: "Strength", isSelected: true) {}
                    StrengthRoutineChoiceChip(label: "Muscle", isSelected: false) {}
                }

                StrengthRoutineSummaryCard(days: 3, exercises: 15, minutes: 45, status: "Ready")

                StrengthRoutineExerciseRow(
                    exercise: StrengthRoutineExerciseDisplay(
                        id: "preview-bench",
                        day: "Monday, Full Body A",
                        position: 1,
                        count: 5,
                        name: "Barbell Bench Press",
                        prescription: "3 × 6 reps",
                        reason: "Primary horizontal press",
                        isIncluded: false,
                        isLocked: true
                    ),
                    onToggleLock: {},
                    onSwap: {}
                )
            }
            .padding(Space.gutter)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }
#endif
