//
//  MuscleInvolvementEditorSheet.swift
//  vivobody
//
//  Focused editor for the graded muscle contribution stored on a
//  catalog exercise. Uses the same five bounded levels as the bundled
//  catalog and applies changes only when Done is tapped.
//

import SwiftUI
import VivoKit

struct MuscleInvolvementEditorSheet: View {
    let onApply: ([String: Double]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: [String: Double]

    init(
        initialSnapshot: [String: Double],
        onApply: @escaping ([String: Double]) -> Void
    ) {
        _snapshot = State(initialValue: initialSnapshot)
        self.onApply = onApply
    }

    private var involvement: Muscle.Involvement {
        Muscle.Involvement(snapshot: snapshot)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    Text("Choose how strongly each muscle contributes. These values shape muscle volume and body insights.")
                        .font(Typography.body)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        muscleGroupSection(group)
                    }

                    if !involvement.hasPrime {
                        Text("Choose at least one Prime muscle.")
                            .font(Typography.body)
                            .foregroundStyle(Tint.danger)
                    }
                }
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .screenBackground()
            .navigationTitle("Muscles Worked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onApply(involvement.snapshot)
                        Haptics.thunk()
                        dismiss()
                    }
                    .disabled(!involvement.hasPrime)
                    .bold()
                }
            }
        }
    }

    private func muscleGroupSection(_ group: MuscleGroup) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(group.displayName)
                .sectionLabelStyle(Opacity.medium)

            VStack(spacing: 0) {
                ForEach(muscles(in: group), id: \.self) { muscle in
                    muscleRow(muscle)
                    if muscle != muscles(in: group).last {
                        SectionDivider()
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Surface.cardTint)
            }
        }
    }

    private func muscleRow(_ muscle: Muscle) -> some View {
        HStack(spacing: Space.md) {
            Text(muscle.displayName)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)

            Spacer(minLength: Space.sm)

            Menu {
                ForEach(Muscle.Involvement.Level.allCases, id: \.self) { level in
                    Button {
                        Haptics.selection()
                        setLevel(level, for: muscle)
                    } label: {
                        if level == self.level(for: muscle) {
                            Label(levelMenuLabel(level), systemImage: "checkmark")
                        } else {
                            Text(levelMenuLabel(level))
                        }
                    }
                }
            } label: {
                Text(levelMenuLabel(level(for: muscle)))
                    .font(Typography.sectionLabel)
                    .foregroundStyle(level(for: muscle) == .none ? Ink.quaternary : Ink.primary)
                    .padding(.horizontal, Space.md)
                    .frame(minHeight: 44)
                    .background {
                        Capsule()
                            .fill(level(for: muscle) == .none ? Surface.cardTint : Tint.inProgress.opacity(0.18))
                    }
            }
            .accessibilityLabel("\(muscle.displayName) involvement")
            .accessibilityValue(levelMenuLabel(level(for: muscle)))
        }
        .frame(minHeight: 60)
    }

    private func muscles(in group: MuscleGroup) -> [Muscle] {
        Muscle.allCases.filter { $0.group == group }
    }

    private func level(for muscle: Muscle) -> Muscle.Involvement.Level {
        Muscle.Involvement.Level(weight: snapshot[muscle.rawValue] ?? 0)
    }

    private func setLevel(_ level: Muscle.Involvement.Level, for muscle: Muscle) {
        if level == .none {
            snapshot.removeValue(forKey: muscle.rawValue)
        } else {
            snapshot[muscle.rawValue] = level.rawValue
        }
    }

    private func levelMenuLabel(_ level: Muscle.Involvement.Level) -> String {
        level == .none ? level.displayName : "\(level.displayName) · \(level.rawValue.formatted())"
    }
}
