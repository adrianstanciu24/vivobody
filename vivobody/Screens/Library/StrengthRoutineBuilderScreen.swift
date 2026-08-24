//
//  StrengthRoutineBuilderScreen.swift
//  vivobody
//
//  Compact planning and one-day-at-a-time review for a generated strength
//  routine. The screen's one decision is: choose a workable starting week,
//  inspect each day, then save every day together as editable templates.
//

import SwiftData
import SwiftUI
import VivoKit

struct StrengthRoutineBuilderScreen: View {
    @Bindable var appState: AppState

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.sessionAnalytics) var sessionAnalytics

    @Query var catalogItems: [ExerciseCatalogItem]

    @State var weekdays: Set<StrengthRoutineWeekday> = [.monday, .wednesday, .friday]
    @State var sessionDuration: StrengthRoutineSessionDuration = .minutes45
    @State var goal: StrengthRoutineGoal = .balanced
    @State var availableEquipment: Set<Equipment> = []
    @State var emphasis: MuscleGroup?
    @State var includedCatalogIDs: Set<String> = []
    @State var excludedCatalogIDs: Set<String> = []
    @State var preferFamiliar = true
    @State var lockedSelections: [StrengthRoutineSlotID: String] = [:]
    @State var familiarityByCatalogID: [String: StrengthRoutineFamiliarity] = [:]

    @State var plan: StrengthRoutinePlan?
    @State var selectedDayValue = StrengthRoutineWeekday.monday.rawValue
    @State var showsPreferences = false
    @State var showsGapDetails = false
    @State var pickerTarget: StrengthRoutinePickerTarget?
    @State var saveError: SaveErrorBox?

    var body: some View {
        NavigationStack {
            Group {
                if plan == nil {
                    planningContent
                } else {
                    reviewContent
                }
            }
            .screenBackground()
            .navigationTitle(plan == nil ? "Build Routine" : "Routine Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomAction
            }
            .sheet(item: $pickerTarget) { target in
                ExercisePickerSheet(purpose: pickerPurpose(for: target)) { item in
                    applyPickedExercise(item, to: target)
                }
            }
            .saveErrorAlert($saveError)
            .task { loadFamiliarity() }
        }
    }

    // MARK: - Planning

    private var planningContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                trainingDaysSection
                goalSection
                durationSection
                equipmentSection
                preferencesSection
            }
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    private var trainingDaysSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: "Training days",
                trailing: "\(weekdays.count) selected",
                accessibilityIdentifier: "strengthRoutineBuilder"
            )
            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    ForEach(weekdayChoices, id: \.self) { weekday in
                        StrengthRoutineChoiceChip(
                            label: WeekdayLabels.short(weekday.calendarValue),
                            isSelected: weekdays.contains(weekday),
                            action: { toggleWeekday(weekday) },
                            accessibilityIdentifier: "strengthRoutineWeekday\(weekday.fullName)"
                        )
                        .accessibilityLabel(weekday.fullName)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Goal")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.sm) { goalChoices }
                VStack(alignment: .leading, spacing: Space.sm) { goalChoices }
            }
        }
    }

    private var goalChoices: some View {
        ForEach(StrengthRoutineGoal.allCases, id: \.self) { choice in
            StrengthRoutineChoiceChip(
                label: choice.title,
                isSelected: goal == choice,
                action: { goal = choice },
                accessibilityIdentifier: "strengthRoutineGoal\(choice.rawValue.capitalized)"
            )
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Session", trailing: "Approximate")
            HStack(spacing: Space.sm) {
                ForEach(StrengthRoutineSessionDuration.allCases, id: \.self) { duration in
                    StrengthRoutineChoiceChip(
                        label: "\(duration.minutes) min",
                        isSelected: sessionDuration == duration,
                        action: { sessionDuration = duration },
                        accessibilityIdentifier: "strengthRoutineDuration\(duration.minutes)"
                    )
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: "Equipment",
                trailing: "Bodyweight included"
            )
            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    ForEach(availableEquipmentChoices, id: \.self) { equipment in
                        StrengthRoutineChoiceChip(
                            label: equipment.displayName,
                            isSelected: availableEquipment.contains(equipment),
                            action: { toggleEquipment(equipment) },
                            accessibilityIdentifier: equipmentIdentifier(equipment)
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var preferencesSection: some View {
        DisclosureGroup(isExpanded: $showsPreferences) {
            StrengthRoutineBuilderPreferences(
                emphasis: $emphasis,
                preferFamiliar: $preferFamiliar,
                includedItems: preferredItems,
                excludedItems: avoidedItems,
                onAddIncluded: { pickerTarget = .include },
                onRemoveIncluded: { includedCatalogIDs.remove($0) },
                onAddExcluded: { pickerTarget = .avoid },
                onRemoveExcluded: { excludedCatalogIDs.remove($0) }
            )
            .padding(.top, Space.md)
            .padding(.bottom, Space.md)
        } label: {
            Text("Preferences")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
        }
        .tint(Ink.tertiary)
    }

    // MARK: - Review

    private var reviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                if let plan {
                    StrengthRoutineSummaryCard(
                        days: plan.days.count,
                        exercises: plan.exercises.count,
                        minutes: sessionDuration.minutes,
                        status: plan.gaps.isEmpty ? "Ready" : "Review gaps"
                    )
                    .accessibilityIdentifier("strengthRoutineReview")

                    if !plan.gaps.isEmpty {
                        StrengthRoutineGapStatus(
                            messages: displayedGapMessages(in: plan),
                            isExpanded: $showsGapDetails
                        )
                    }

                    StrengthRoutineDaySelector(
                        days: dayChoices(for: plan),
                        selection: $selectedDayValue
                    )

                    selectedDaySection(in: plan)

                    Button(action: regenerateUnlocked) {
                        Label("Regenerate Unlocked", systemImage: "arrow.clockwise")
                            .font(Typography.headline)
                            .foregroundStyle(Ink.secondary)
                            .frame(maxWidth: .infinity, minHeight: Space.rowMin)
                            .contentCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("strengthRoutineRegenerate")
                }
            }
            .padding(.top, Space.md)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    @ViewBuilder
    private func selectedDaySection(in plan: StrengthRoutinePlan) -> some View {
        if let day = selectedDay(in: plan) {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(
                    title: day.title,
                    trailing: "\(day.slots.compactMap(\.exercise).count) exercises"
                )

                let populatedSlots = day.slots.filter { $0.exercise != nil }
                ForEach(Array(populatedSlots.enumerated()), id: \.element.id) { index, slot in
                    if let exercise = slot.exercise {
                        StrengthRoutineExerciseRow(
                            exercise: exerciseDisplay(
                                exercise,
                                in: slot,
                                day: day,
                                position: index + 1,
                                count: populatedSlots.count
                            ),
                            onToggleLock: { toggleLock(slot) },
                            onSwap: { pickerTarget = .swap(slot.id) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if plan == nil {
                Button("Cancel") { dismiss() }
            } else {
                Button("Plan") {
                    plan = nil
                    lockedSelections.removeAll()
                }
            }
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            if plan == nil {
                bottomButton(
                    title: "Build Routine",
                    enabled: canBuild,
                    identifier: "strengthRoutineBuild",
                    action: buildRoutine
                )
            } else {
                bottomButton(
                    title: "Save Routine",
                    enabled: canSavePlan,
                    identifier: "strengthRoutineSave",
                    action: savePlan
                )
            }
        }
        .background(Surface.background)
    }

    private func bottomButton(
        title: String,
        enabled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.md)
    }

    // MARK: - State adapters

    var builderInput: StrengthRoutineBuilderInput {
        StrengthRoutineBuilderInput(
            weekdays: weekdayChoices.filter(weekdays.contains),
            sessionDuration: sessionDuration,
            goal: goal,
            availableEquipment: availableEquipment,
            emphasis: emphasis,
            includedCatalogIDs: includedCatalogIDs,
            excludedCatalogIDs: excludedCatalogIDs,
            preferFamiliar: preferFamiliar,
            lockedSelections: lockedSelections
        )
    }

    var candidates: [StrengthRoutineCandidate] {
        catalogItems.compactMap { item in
            guard
                let catalogID = item.catalogID,
                item.modality.supportsHardSetAnalytics,
                let record = CatalogData.record(forCatalogID: catalogID)
            else { return nil }
            return StrengthRoutineCandidate(
                record: record,
                isFavorite: item.isFavorite,
                familiarity: familiarityByCatalogID[catalogID] ?? .none
            )
        }
    }

    private var canBuild: Bool {
        (2 ... 4).contains(weekdays.count)
    }

    private var canSavePlan: Bool {
        guard let plan else { return false }
        return !plan.days.isEmpty && !plan.hasBlockingGaps
    }

    private var availableEquipmentChoices: [Equipment] {
        let authored = Set(catalogItems.filter { item in
            item.catalogID != nil && item.modality.supportsHardSetAnalytics
        }.map(\.equipment))
        return Equipment.allCases.filter {
            $0 != .bodyweight && authored.contains($0)
        }
    }

    var weekdayChoices: [StrengthRoutineWeekday] {
        WeekdayLabels.ordered().compactMap(StrengthRoutineWeekday.init(rawValue:))
    }

    private var preferredItems: [ExerciseCatalogItem] {
        preferenceItems(matching: includedCatalogIDs)
    }

    private var avoidedItems: [ExerciseCatalogItem] {
        preferenceItems(matching: excludedCatalogIDs)
    }
}

enum StrengthRoutinePickerTarget: Identifiable {
    case include
    case avoid
    case swap(StrengthRoutineSlotID)

    var id: String {
        switch self {
        case .include: "include"
        case .avoid: "avoid"
        case let .swap(slotID):
            "swap-\(slotID.weekday.rawValue)-\(slotID.kind.title)-\(slotID.occurrence)"
        }
    }
}
