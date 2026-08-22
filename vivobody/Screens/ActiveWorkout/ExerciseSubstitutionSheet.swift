//
//  ExerciseSubstitutionSheet.swift
//  vivobody
//
//  Focused live-workout replacement surface. It turns the pure catalog
//  recommendations into one selected alternative, one equipment constraint,
//  and one explicit commit action; persistence remains owned by
//  WorkoutSessionController.
//

import SwiftData
import SwiftUI
import VivoKit

/// Value snapshot retained by the sheet so a successful controller mutation
/// can delete the source Exercise without invalidating presentation state.
struct ExerciseSubstitutionTarget: Identifiable {
    let id: UUID
    let name: String
    let subject: ExerciseSubstitution.Subject
    let hasCompletedSets: Bool

    init(_ exercise: Exercise) {
        id = exercise.id
        name = exercise.name
        subject = ExerciseSubstitution.Subject(exercise)
        hasCompletedSets = exercise.orderedSets.contains { $0.isCompleted }
    }
}

/// Couples a controller result with the standard save error captured at the
/// same boundary, letting the nested sheet surface failures without dismissing.
struct ExerciseSubstitutionCommit {
    let result: ExerciseReplacementResult
    let saveError: SaveErrorBox?
}

struct ExerciseSubstitutionSheet: View {
    let target: ExerciseSubstitutionTarget
    let onReplace: (ExerciseCatalogItem) -> ExerciseSubstitutionCommit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionAnalytics) private var sessionAnalytics

    @Query(sort: \ExerciseCatalogItem.name)
    private var catalogItems: [ExerciseCatalogItem]

    @State private var selectedCandidateID: UUID?
    @State private var selectedEquipment: Equipment?
    @State private var selectedDetent: PresentationDetent = .large
    @State private var showsAllAlternatives = false
    @State private var becameBlocked = false
    @State private var familiarityByHistoryKey:
        [String: ExerciseSubstitution.Familiarity] = [:]
    @State private var issue: ReplacementIssue?
    @State private var saveError: SaveErrorBox?

    init(
        target: ExerciseSubstitutionTarget,
        onReplace: @escaping (ExerciseCatalogItem) -> ExerciseSubstitutionCommit
    ) {
        self.target = target
        self.onReplace = onReplace
        _selectedCandidateID = State(initialValue: nil)
        _selectedEquipment = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        sourceIdentity
                        if isBlocked {
                            blockedState
                        } else {
                            equipmentFilters
                            recommendationList
                        }
                    }
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xxl)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
            .navigationTitle("Replace exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) { commitBar }
        }
        .presentationDetents(
            presentationDetents,
            selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
        .task(id: target.id) { loadFamiliarity() }
        .alert(item: $issue) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                dismissButton: .default(Text("OK")) {
                    if issue.dismissesSheet { dismiss() }
                }
            )
        }
        .saveErrorAlert($saveError)
    }

    private var presentationDetents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
    }

    private var isBlocked: Bool {
        target.hasCompletedSets || becameBlocked
    }

    private var sourceIdentity: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Replacing")
                .panelLegendType()
            Text(target.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Replacing \(target.name)")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("exerciseSubstitutionSheet")
    }

    private var blockedState: some View {
        ContentUnavailableView {
            Label("Already logged", systemImage: "checkmark.circle")
        } description: {
            Text("Replace is available before this exercise's first completed set. Your logged work stays attached to \(target.name).")
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Already logged. Replace is available before this exercise's first completed set. Your logged work stays attached to \(target.name)."
        )
        .accessibilityIdentifier("exerciseReplacementBlocked")
    }

    private var equipmentFilters: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Available equipment")
                .sectionHeadingStyle()
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        equipmentChip(nil, label: "Any")
                        ForEach(equipmentOptions, id: \.self) { equipment in
                            equipmentChip(equipment, label: equipment.displayName)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -Space.gutter)
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        }
    }

    private func equipmentChip(
        _ equipment: Equipment?,
        label: String
    ) -> some View {
        let selected = selectedEquipment == equipment
        let identifier = equipment?.rawValue ?? "all"
        return Button {
            Haptics.selection()
            selectedEquipment = equipment
            selectedCandidateID = nil
        } label: {
            Text(label)
                .font(Typography.sectionLabel)
                .foregroundStyle(selected ? Tint.onAccent : Ink.secondary)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
                .coloredGlassControl(
                    cornerRadius: Radius.pill,
                    fill: selected ? Tint.inProgress : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("replacementEquipment-\(identifier)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private var recommendationList: some View {
        if allRecommendations.isEmpty {
            ContentUnavailableView {
                Label("No compatible alternatives", systemImage: "dumbbell")
            } description: {
                Text(emptyMessage)
            } actions: {
                if selectedEquipment != nil {
                    Button("Show any equipment") {
                        selectedEquipment = nil
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(
                    title: showsAllAlternatives
                        ? "Compatible alternatives"
                        : "Best alternatives"
                )

                ForEach(visibleRecommendations, id: \.candidate.id) { recommendation in
                    recommendationButton(recommendation)
                }

                if !showsAllAlternatives, allRecommendations.count > 3 {
                    Button {
                        Haptics.soft()
                        showsAllAlternatives = true
                    } label: {
                        Text("More alternatives")
                            .font(Typography.headline)
                            .foregroundStyle(Ink.secondary)
                            .frame(maxWidth: .infinity, minHeight: Space.rowMin)
                            .coloredGlassControl(cornerRadius: Radius.card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("showMoreExerciseReplacements")
                }
            }
        }
    }

    private var emptyMessage: String {
        if let selectedEquipment {
            return "No compatible exercises use \(selectedEquipment.displayName.lowercased())."
        }
        return "No other catalog exercise preserves this workout's tracking style."
    }

    private var equipmentOptions: [Equipment] {
        let represented = Set(unfilteredRecommendations.map(\.candidate.equipment))
        return Equipment.allCases.filter(represented.contains)
    }

    private var unfilteredRecommendations: [ExerciseSubstitution.Recommendation] {
        ExerciseSubstitution.rank(
            anchor: target.subject,
            candidates: catalogItems,
            familiarityByHistoryKey: familiarityByHistoryKey,
            limit: catalogItems.count
        )
    }

    private var allRecommendations: [ExerciseSubstitution.Recommendation] {
        guard let selectedEquipment else { return unfilteredRecommendations }
        return ExerciseSubstitution.rank(
            anchor: target.subject,
            candidates: catalogItems,
            availableEquipment: [selectedEquipment],
            familiarityByHistoryKey: familiarityByHistoryKey,
            limit: catalogItems.count
        )
    }

    private var visibleRecommendations: [ExerciseSubstitution.Recommendation] {
        showsAllAlternatives
            ? allRecommendations
            : Array(allRecommendations.prefix(3))
    }

    private var selectedRecommendation: ExerciseSubstitution.Recommendation? {
        if let selectedCandidateID,
           let selected = allRecommendations.first(where: {
               $0.candidate.id == selectedCandidateID
           })
        {
            return selected
        }
        return allRecommendations.first
    }

    private func recommendationButton(
        _ recommendation: ExerciseSubstitution.Recommendation
    ) -> some View {
        let selected = recommendation.candidate.id == selectedRecommendation?.candidate.id
        return Button {
            Haptics.selection()
            selectedCandidateID = recommendation.candidate.id
        } label: {
            RecommendationLabel(
                recommendation: recommendation,
                isSelected: selected
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recommendationAccessibilityLabel(recommendation))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint("Selects this replacement")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(candidateIdentifier(recommendation.candidate))
    }

    private var commitBar: some View {
        Button {
            commitReplacement()
        } label: {
            Text("Replace exercise")
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.sm)
        }
        .buttonStyle(PrimaryButtonStyle(compact: true))
        .disabled(isBlocked || selectedRecommendation == nil)
        .opacity(isBlocked || selectedRecommendation == nil ? 0.45 : 1)
        .accessibilityLabel(commitAccessibilityLabel)
        .accessibilityIdentifier("confirmExerciseReplacement")
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.sm)
    }

    private var commitAccessibilityLabel: String {
        guard !isBlocked,
              let candidate = selectedRecommendation?.candidate
        else {
            return "Replace exercise unavailable"
        }
        return "Replace \(target.name) with \(candidate.name)"
    }

    private func commitReplacement() {
        guard !isBlocked, let selectedRecommendation else { return }
        let commit = onReplace(selectedRecommendation.candidate)
        switch commit.result {
        case .replaced:
            Haptics.soft()
            dismiss()
        case let .blocked(reason):
            handleBlock(reason)
        case .saveFailed:
            saveError = commit.saveError
                ?? SaveErrorBox(ExerciseSubstitutionSaveFailure())
        }
    }

    private func handleBlock(_ reason: ExerciseReplacementBlockReason) {
        Haptics.caution()
        switch reason {
        case .exerciseAlreadyStarted:
            becameBlocked = true
        case .staleSession, .exerciseNotFound:
            issue = ReplacementIssue(
                title: "Workout changed",
                message: "This exercise is no longer available to replace.",
                dismissesSheet: true
            )
        case .persistenceUnavailable:
            issue = ReplacementIssue(
                title: "Replacement unavailable",
                message: "Vivobody couldn't access the active workout. Try again.",
                dismissesSheet: false
            )
        }
    }

    private func loadFamiliarity() {
        guard let history = sessionAnalytics?.resolvedExerciseHistory(
            in: modelContext
        ) else { return }
        familiarityByHistoryKey = history.mapValues { summary in
            ExerciseSubstitution.Familiarity(
                sessionCount: summary.sessionCount,
                lastPerformedAt: summary.latestPerformanceDate
            )
        }
    }

    private func recommendationAccessibilityLabel(
        _ recommendation: ExerciseSubstitution.Recommendation
    ) -> String {
        "\(recommendation.candidate.name), \(recommendation.candidate.equipment.displayName). \(recommendation.explanation)"
    }

    private func candidateIdentifier(_ candidate: ExerciseCatalogItem) -> String {
        "replacementCandidate-\(candidate.catalogID ?? candidate.id.uuidString)"
    }
}

private struct RecommendationLabel: View {
    let recommendation: ExerciseSubstitution.Recommendation
    let isSelected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity

            if isSelected {
                tradeoffLedger
            }
        }
        .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
        .contentCard(tint: isSelected ? Tint.inProgress : nil, bright: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            recommendationHeader

            Text(recommendation.candidate.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private var tradeoffLedger: some View {
        VStack(spacing: 0) {
            SectionDivider()

            factLine(
                label: "Keeps",
                value: recommendation.preserves.first?.glanceCopy
                    ?? "Compatible workout format"
            )

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            factLine(
                label: "Changes",
                value: recommendation.changes.first?.glanceCopy
                    ?? "Exact exercise variant"
            )
        }
        .padding(.horizontal, Space.lg)
    }

    @ViewBuilder
    private var recommendationHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    tierText
                    Spacer(minLength: Space.sm)
                    selectionIcon
                }
                equipmentText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                tierText
                Spacer(minLength: Space.sm)
                equipmentText
                selectionIcon
            }
        }
    }

    private var tierText: some View {
        Text(recommendation.tier.copy)
            .font(Typography.sectionLabel)
            .foregroundStyle(Tint.primaryText)
    }

    private var equipmentText: some View {
        Text(recommendation.candidate.equipment.displayName)
            .panelLegendType()
    }

    private var selectionIcon: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Tint.inProgress : Ink.quaternary)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func factLine(label: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xs) {
                factLabel(label)
                factValue(value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.sm)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                factLabel(label)
                    .frame(width: 62, alignment: .leading)
                factValue(value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.sm)
        }
    }

    private func factLabel(_ value: String) -> some View {
        Text(value)
            .panelLegendType()
            .foregroundStyle(value == "Keeps" ? Tint.primaryText : Ink.tertiary)
    }

    private func factValue(_ value: String) -> some View {
        Text(value)
            .font(Typography.sectionLabel)
            .foregroundStyle(Ink.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ReplacementIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissesSheet: Bool
}

private struct ExerciseSubstitutionSaveFailure: LocalizedError {
    var errorDescription: String? {
        "The original exercise was restored. Try replacing it again."
    }
}
