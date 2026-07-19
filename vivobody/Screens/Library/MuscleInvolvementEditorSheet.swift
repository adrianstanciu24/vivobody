//
//  MuscleInvolvementEditorSheet.swift
//  vivobody
//
//  Focused editor for the categorical muscle roles stored on a
//  catalog exercise. Primary and secondary roles drive hard-set
//  analytics; stabilizers remain visual context only. Changes apply
//  only when Done is tapped.
//

import SwiftUI
import VivoKit

struct MuscleInvolvementEditorSheet: View {
    let onApply: ([String: Double]) -> Void
    let requiresPrimary: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: [String: Double]

    init(
        initialSnapshot: [String: Double],
        requiresPrimary: Bool = true,
        onApply: @escaping ([String: Double]) -> Void
    ) {
        _snapshot = State(initialValue: initialSnapshot)
        self.requiresPrimary = requiresPrimary
        self.onApply = onApply
    }

    private var involvement: Muscle.Involvement {
        Muscle.Involvement(snapshot: snapshot)
    }

    /// An explicit empty snapshot means “use the coarse group preset”
    /// in the persisted model. Requiring at least one selected muscle
    /// prevents a conditioning or mobility exercise from silently
    /// acquiring that fallback classification after Save.
    private var canApply: Bool {
        !involvement.isEmpty && (!requiresPrimary || involvement.hasPrimary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    Text(requiresPrimary
                        ? "Choose each muscle's role. Primary and secondary muscles shape training volume; stabilizers remain visible without earning hard-set credit."
                        : "Choose any muscles that should remain visible for this exercise. This modality does not earn hard-set volume.")
                        .font(Typography.body)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        muscleGroupSection(group)
                    }

                    if involvement.isEmpty {
                        Text("Choose at least one muscle.")
                            .font(Typography.body)
                            .foregroundStyle(Tint.danger)
                    } else if requiresPrimary, !involvement.hasPrimary {
                        Text("Choose at least one Primary muscle.")
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
                    .disabled(!canApply)
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
                Button {
                    Haptics.selection()
                    setRole(nil, for: muscle)
                } label: {
                    if role(for: muscle) == nil {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }

                ForEach(MuscleRole.allCases, id: \.self) { role in
                    Button {
                        Haptics.selection()
                        setRole(role, for: muscle)
                    } label: {
                        if role == self.role(for: muscle) {
                            Label(role.displayName, systemImage: "checkmark")
                        } else {
                            Text(role.displayName)
                        }
                    }
                }
            } label: {
                Text(role(for: muscle)?.displayName ?? "None")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(role(for: muscle) == nil ? Ink.quaternary : Ink.primary)
                    .padding(.horizontal, Space.md)
                    .frame(minHeight: 44)
                    .background {
                        Capsule()
                            .fill(role(for: muscle) == nil ? Surface.cardTint : Tint.inProgress.opacity(0.18))
                    }
            }
            .accessibilityLabel("\(muscle.displayName) involvement")
            .accessibilityValue(role(for: muscle)?.displayName ?? "None")
        }
        .frame(minHeight: 60)
    }

    private func muscles(in group: MuscleGroup) -> [Muscle] {
        Muscle.allCases.filter { $0.group == group }
    }

    private func role(for muscle: Muscle) -> MuscleRole? {
        involvement.roles[muscle]
    }

    private func setRole(_ role: MuscleRole?, for muscle: Muscle) {
        if let role {
            snapshot[muscle.rawValue] = role.visualIntensity
        } else {
            snapshot.removeValue(forKey: muscle.rawValue)
        }
    }
}
