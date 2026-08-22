//
//  ExerciseComparisonScreen.swift
//  vivobody
//
//  Visual, instrument-first exercise comparison reached from Exercise
//  Detail. A persistent A/B identity key and three-mode selector keep the
//  screen navigable; each mode shows one focused comparison instead of a
//  long document. All conclusions remain catalog-authored and descriptive.
//

import SwiftUI
import VivoKit

// MARK: - Detail screen entry

extension ExerciseDetailScreen {
    /// Detail-screen entry beside the existing instructions drill-out.
    var compareLink: some View {
        Button {
            startComparison()
        } label: {
            KitRow(
                title: "Compare with another exercise",
                leading: Image(systemName: "arrow.left.arrow.right")
            ) {
                Image(systemName: "chevron.right")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens exercise comparison")
        .accessibilityIdentifier("exercise-compare")
    }
}

enum ExerciseComparisonPanel: String, CaseIterable, Hashable {
    case muscles
    case movement
    case tracking

    var title: String {
        switch self {
        case .muscles: "Muscles"
        case .movement: "Movement"
        case .tracking: "Tracking"
        }
    }
}

struct ExerciseComparisonScreen: View {
    let anchor: ExerciseCatalogItem
    let other: ExerciseCatalogItem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss

    @State var selectedPanel: ExerciseComparisonPanel = .muscles
    @State var anatomySide: ExerciseComparison.Side = .anchor
    @State var muscleScope: ExerciseComparison.AnatomyScope = .trainingVolume
    @State var anatomyScope: ExerciseComparison.AnatomyScope = .trainingVolume
    @State var showsDirectionExplanation = false
    @State var showsTrackingExplanation = false

    /// Shared by the focused panels in the companion source files.
    var comparison: ExerciseComparison {
        ExerciseComparison(anchor: anchor, other: other)
    }

    var theme: BodyModelTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: Space.xxl) {
                    Color.clear
                        .frame(height: 1)
                        .id("comparison-panel-top")

                    selectedPanelContent
                        .id(selectedPanel)
                }
                .padding(.top, Space.sm)
                .padding(.bottom, Space.section)
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .onChange(of: selectedPanel) { _, _ in
                scrollToPanelTop(proxy)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            comparisonControlDeck
        }
        .screenBackground()
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("comparison-done")
            }
        }
    }

    @ViewBuilder
    private var selectedPanelContent: some View {
        switch selectedPanel {
        case .muscles:
            musclesPanel
        case .movement:
            movementPanel
        case .tracking:
            trackingPanel
        }
    }

    // MARK: - Persistent controls

    private var comparisonControlDeck: some View {
        VStack(spacing: Space.sm) {
            comparisonIdentityKey
            panelSelector
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.sm)
        .background(Surface.background)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
    }

    private var comparisonIdentityKey: some View {
        HStack(spacing: Space.md) {
            identityItem(label: "A", name: anchor.name, tint: .accent)
            Rectangle()
                .fill(Surface.edge)
                .frame(width: 1, height: 34)
                .accessibilityHidden(true)
            identityItem(label: "B", name: other.name, tint: .compare)
        }
        .frame(maxWidth: .infinity, minHeight: Space.tapMin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Comparing \(anchor.name) with \(other.name)")
    }

    private func identityItem(
        label: String,
        name: String,
        tint: MuscleMapTint
    ) -> some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Text(label)
                .font(Typography.metricInline)
                .foregroundStyle(comparisonLabelColor(tint))

            Text(name)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var panelSelector: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(ExerciseComparisonPanel.allCases, id: \.self) { panel in
                    panelButton(panel)
                }
            }
            .padding(4)
            .coloredGlassControl(cornerRadius: Radius.pill)
        }
    }

    private func panelButton(_ panel: ExerciseComparisonPanel) -> some View {
        let isSelected = selectedPanel == panel
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            selectedPanel = panel
        } label: {
            Text(panel.title)
                .font(Typography.sectionHeading)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: Space.tapMin)
                .background {
                    if isSelected {
                        Color.clear
                            .coloredGlassControl(
                                cornerRadius: Radius.pill,
                                fill: Tint.inProgress
                            )
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("comparison-panel-\(panel.rawValue)")
    }

    private func scrollToPanelTop(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("comparison-panel-top", anchor: .top)
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                proxy.scrollTo("comparison-panel-top", anchor: .top)
            }
        }
    }

    // MARK: - Comparison colors

    func comparisonLabelColor(_ tint: MuscleMapTint) -> Color {
        color(ExerciseComparisonPalette.labelRGB(for: tint, theme: theme))
    }

    func comparisonControlFillColor(_ tint: MuscleMapTint) -> Color {
        color(ExerciseComparisonPalette.controlFillRGB(for: tint))
    }

    var comparisonControlForegroundColor: Color {
        color(ExerciseComparisonPalette.controlForegroundRGB)
    }

    func anatomyTintColor(_ tint: MuscleMapTint, intensity: Double = 1) -> Color {
        let rgb = MuscleColor.rgb(
            for: MuscleMapChannels(intensity: intensity, tint: tint),
            theme: theme
        )
        return color(rgb)
    }

    private func color(_ rgb: MuscleColor.RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

#if DEBUG
    #Preview("Exercise comparison instrument") {
        NavigationStack {
            ExerciseComparisonScreen(
                anchor: ExerciseCatalogItem(
                    catalogID: "incline-bench-press",
                    name: "Incline Bench Press",
                    group: .chest,
                    defaultWeight: 115,
                    equipment: .barbell,
                    mechanic: .compound,
                    trainingRole: .push,
                    pattern: .push,
                    direction: .diagonal,
                    planes: [.sagittal],
                    execution: ExecutionInstructions(
                        startingPosition: "Lie on an incline bench with the bar above your shoulders.",
                        movement: "Press the bar upward until your elbows are straight.",
                        endpoint: "Finish with the bar above your upper chest.",
                        returnPhase: "Lower the bar under control.",
                        controlledJoints: "Keep your feet planted and shoulders pulled back.",
                        supportAndPosture: "Stay supported by the bench with a slight arch.",
                        disqualifyingCompensations: ["Do not bounce the bar."],
                        sideOrDirection: nil
                    ),
                    muscleInvolvement: Muscle.Involvement(contributions: [
                        .init(muscle: .pectoralisMajorClavicular, role: .primary),
                        .init(muscle: .deltoidAnterior, role: .secondary),
                        .init(muscle: .triceps, role: .secondary),
                    ])
                ),
                other: ExerciseCatalogItem(
                    catalogID: "overhead-press",
                    name: "Standing Overhead Press",
                    group: .shoulders,
                    defaultWeight: 95,
                    equipment: .barbell,
                    mechanic: .compound,
                    trainingRole: .push,
                    pattern: .push,
                    direction: .vertical,
                    planes: [.sagittal, .frontal],
                    execution: ExecutionInstructions(
                        startingPosition: "Stand with the bar at your collarbones.",
                        movement: "Press the bar overhead until your elbows are straight.",
                        endpoint: "Finish with the bar over the middle of your feet.",
                        returnPhase: "Lower the bar under control.",
                        controlledJoints: "Keep your ribs down and knees unlocked.",
                        supportAndPosture: "Stand unsupported without leaning back.",
                        disqualifyingCompensations: ["Do not drive with the legs."],
                        sideOrDirection: nil
                    ),
                    muscleInvolvement: Muscle.Involvement(contributions: [
                        .init(muscle: .deltoidAnterior, role: .primary),
                        .init(muscle: .pectoralisMajorClavicular, role: .secondary),
                        .init(muscle: .triceps, role: .secondary),
                        .init(muscle: .externalRotators, role: .stabilizer),
                    ])
                )
            )
        }
        .preferredColorScheme(.dark)
    }
#endif
