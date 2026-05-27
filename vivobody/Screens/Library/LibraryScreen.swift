//
//  LibraryScreen.swift
//  vivobody
//
//  Two-segment browser for everything reusable in the app:
//    • Templates — the user's saved workout plans
//    • Exercises — the full exercise catalog (90 stock + customs)
//
//  Why a segmented control instead of a tab: both surfaces serve
//  the same mental model ("reusable workout content") and live at
//  the same level of importance. Tab-count stays at four (Today /
//  History / Library / Me). Matches Notes / Reminders / Music
//  patterns where collections + items share one tab.
//
//  Toolbar "+" is contextual:
//    • Templates segment → opens a name-prompt alert → creates a
//      blank template; user enters its detail to add exercises.
//    • Exercises segment → opens CustomExerciseEditorSheet in
//      .create mode → adds a new entry to the catalog.
//
//  Search bar (always visible, nav-bar drawer) filters whichever
//  segment is active: templates match by name; exercises match by
//  name or alias.
//
//  The Exercises segment shares the History list's journal
//  vocabulary: monospaced caps group headers with a "12 EXERCISES
//  · 5 TRACKED" right-aligned subtitle; and a two-tier row split
//  keyed on recency. Anything lifted in the last 14 days gets the
//  rich glass-card treatment with `CarvedVolumeText` on the right
//  (weight×reps, gold underline if all-time best). Everything else
//  collapses to a tighter chip — smaller carved digits if there's
//  older history, a quiet catalog default if there isn't.
//

import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext

    @State private var segment: LibrarySegment = .templates
    @State private var searchText: String = ""

    /// New-template name-prompt alert state.
    @State private var isCreatingTemplate: Bool = false
    @State private var newTemplateName: String = ""

    /// Custom-exercise editor sheet target. `.create` for the "+"
    /// toolbar on the Exercises segment; `.edit(item)` for context
    /// menu Edit on a row.
    @State private var customExerciseTarget: CatalogEditorTarget? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                segmentPicker

                // Two distinct content views — each owns its own
                // SwiftData query + filter state so neither one
                // does extra work when the other segment is active.
                switch segment {
                case .templates:
                    LibraryTemplatesContent(
                        appState: appState,
                        searchText: searchText,
                        onRequestNew: presentNewTemplateAlert
                    )
                case .exercises:
                    LibraryExercisesContent(
                        searchText: searchText,
                        customExerciseTarget: $customExerciseTarget
                    )
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: searchPrompt
        )
        .toolbar { toolbar }
        .alert("New Template", isPresented: $isCreatingTemplate) {
            TextField("Name", text: $newTemplateName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
            Button("Create") {
                createTemplate(named: newTemplateName)
                newTemplateName = ""
            }
        } message: {
            Text("Pick a name. You can rename it later by tapping the title on its detail screen.")
        }
        .sheet(item: $customExerciseTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
    }

    // MARK: - Segment picker

    /// Custom Liquid Glass segmented picker. Replaces the stock
    /// `.segmented` Picker style — which renders as a flat UIKit
    /// pill that doesn't speak the rest of the app's carved-glass
    /// vocabulary — with a capsule that uses `.glassEffect()`,
    /// a rim stroke, and a brighter glass pill that slides between
    /// segments via `matchedGeometryEffect`. Same material language
    /// as the equipment chip strip directly below it.
    private var segmentPicker: some View {
        GlassSegmentedPicker(selection: $segment)
            .accessibilityLabel("Library segment")
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 14)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: handlePlus) {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel(plusAccessibilityLabel)
        }
    }

    private func handlePlus() {
        switch segment {
        case .templates:
            presentNewTemplateAlert()
        case .exercises:
            customExerciseTarget = .create
        }
    }

    private var plusAccessibilityLabel: String {
        switch segment {
        case .templates: return "New template"
        case .exercises: return "Create custom exercise"
        }
    }

    // MARK: - Search prompt

    /// Search field placeholder switches per segment so the user
    /// knows what's being searched. Subtle but reduces "what does
    /// this search?" friction.
    private var searchPrompt: String {
        switch segment {
        case .templates: return "Search templates"
        case .exercises: return "Search exercises"
        }
    }

    // MARK: - Mutations

    private func presentNewTemplateAlert() {
        newTemplateName = ""
        isCreatingTemplate = true
    }

    private func createTemplate(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0

        let template = WorkoutTemplate(name: trimmed, sortOrder: count)
        modelContext.insert(template)
        try? modelContext.save()
        Haptics.soft()
    }
}

// MARK: - Segment enum

enum LibrarySegment: String, CaseIterable, Identifiable {
    case templates
    case exercises
    var id: String { rawValue }
    var label: String {
        switch self {
        case .templates: return "Templates"
        case .exercises: return "Exercises"
        }
    }
}

// MARK: - Glass segmented picker

/// Two-segment glass capsule. Outer shell is a `.glassEffect()`
/// pill with the project's standard rim stroke. The selection
/// indicator is a second, brighter glass pill that sits inside —
/// it animates between segments via `matchedGeometryEffect`, so
/// switching from Templates → Exercises feels like the highlight
/// glides through liquid rather than swapping in place. Selection
/// fires a `Haptics.selection()` tick to match the equipment
/// chip strip below.
private struct GlassSegmentedPicker: View {
    @Binding var selection: LibrarySegment
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibrarySegment.allCases) { segment in
                segmentButton(segment)
            }
        }
        .padding(4)
        .background {
            Capsule().fill(Surface.cardTint)
        }
        .glassEffect(.regular, in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Surface.edgeBright,
                            Surface.edge.opacity(0.6),
                            Surface.edge.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }

    private func segmentButton(_ segment: LibrarySegment) -> some View {
        let isSelected = selection == segment
        return Button {
            guard selection != segment else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selection = segment
            }
            Haptics.selection()
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay {
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.32),
                                            Color.white.opacity(0.10)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.6
                                )
                        }
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.10),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                        .matchedGeometryEffect(id: "selectionPill", in: indicatorNamespace)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                }
                Text(segment.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(segment.label)
    }
}

// MARK: - Templates content

/// Templates segment — list of saved workout plans. Swipe-left to
/// delete, tap to enter detail. Empty state offers an inline create
/// button. Inherits search text from the parent and filters by name.
private struct LibraryTemplatesContent: View {
    @Bindable var appState: AppState
    let searchText: String
    let onRequestNew: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder)])
    private var templates: [WorkoutTemplate]

    @State private var deletingTemplate: WorkoutTemplate? = nil

    private var filtered: [WorkoutTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return templates }
        return templates.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                noMatchesState
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
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(filtered) { template in
                NavigationLink {
                    TemplateDetailScreen(
                        template: template,
                        appState: appState
                    )
                } label: {
                    TemplateCard(template: template)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 8, trailing: 22))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
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
    }

    // MARK: - Empty states

    /// Empty state. The orange CTA is the single accent anchor on
    /// the page — so the sphere goes neutral (white-glass pearl)
    /// and the icon goes neutral too (ghostly chalk-on-glass). The
    /// two-tone white palette keeps the secondary spines readable
    /// against the sphere's mid-tone radial without re-introducing
    /// orange that would compete with the CTA below.
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                GlassSphere(size: 132, tint: .white)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white.opacity(0.80), .white.opacity(0.40))
                    .symbolEffect(.breathe.pulse, options: .repeating)
            }
            .shadow(color: .white.opacity(0.10), radius: 24, y: 0)
            .shadow(color: .black.opacity(0.50), radius: 18, y: 8)

            VStack(spacing: 8) {
                Text("No templates yet")
                    .sectionHeadingStyle()

                Text("Build a reusable workout — pick exercises, set target reps and weight. Start any time from here.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button(action: onRequestNew) {
                Text("Create Template")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(Tint.primary)
                    )
                    .primaryGlow(Tint.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("No templates match \"\(searchText)\".")
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    // MARK: - Plumbing

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
        for (i, t) in templates.enumerated() {
            t.sortOrder = i
        }
        try? modelContext.save()
        Haptics.soft()
        deletingTemplate = nil
    }
}

// MARK: - Exercises content

/// Exercises segment — browsable catalog. Tap an exercise row to
/// push its detail screen (no commit CTA in this context). Long-
/// press for Edit / Delete via context menu. Equipment filter strip
/// at the top mirrors the picker's chips so the two surfaces feel
/// continuous.
private struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var customExerciseTarget: CatalogEditorTarget?

    @Environment(\.modelContext) private var modelContext

    @Query private var items: [ExerciseCatalogItem]

    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var equipmentFilter: Equipment? = nil
    @State private var pendingDeleteItem: ExerciseCatalogItem? = nil

    private var lastInstanceLookup: [String: LastExerciseInstance] {
        completedSessions.lastInstanceByExercise()
    }

    var body: some View {
        VStack(spacing: 0) {
            equipmentFilterStrip

            if filteredGroups.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .alert(
            "Delete \"\(pendingDeleteItem?.name ?? "exercise")\"?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let item = pendingDeleteItem {
                    delete(item)
                }
                pendingDeleteItem = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: {
            Text("This removes the exercise from the catalog. Templates and history that already reference it stay intact.")
        }
    }

    // MARK: - Filter / group

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var scope = items
        if let filter = equipmentFilter {
            scope = scope.filter { $0.equipment == filter }
        }
        if !trimmed.isEmpty {
            scope = scope.filter { item in
                if item.name.lowercased().contains(trimmed) { return true }
                return item.aliases.contains { $0.lowercased().contains(trimmed) }
            }
        }
        return scope.groupedByMuscle
    }

    private var availableEquipment: Set<Equipment> {
        Set(items.map(\.equipment))
    }

    // MARK: - Equipment filter strip

    @ViewBuilder
    private var equipmentFilterStrip: some View {
        if availableEquipment.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chip(nil, label: "All", symbol: nil)
                    ForEach(Equipment.allCases, id: \.self) { e in
                        if availableEquipment.contains(e) {
                            chip(e, label: e.displayName, symbol: e.symbol)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.bottom, 14)
        }
    }

    private func chip(_ value: Equipment?, label: String, symbol: String?) -> some View {
        let isSelected = equipmentFilter == value
        return Button {
            Haptics.selection()
            equipmentFilter = value
        } label: {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background {
                if isSelected {
                    Capsule().fill(Tint.primary)
                } else {
                    Capsule().fill(Color.white.opacity(0.06))
                }
            }
            .overlay {
                Capsule().stroke(
                    isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.12),
                    lineWidth: 0.5
                )
            }
            .shadow(
                color: isSelected ? Tint.primary.opacity(0.40) : .clear,
                radius: 14, y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(filteredGroups, id: \.group) { section in
                    groupSection(group: section.group, items: section.items)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        let trackedCount = items.reduce(into: 0) { acc, item in
            if lastInstanceLookup[item.name.lowercased()] != nil { acc += 1 }
        }

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(group: group, total: items.count, tracked: trackedCount)
            VStack(spacing: 12) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    /// Journal-style group header — accent dash + monospaced caps
    /// muscle name on the left, "12 EXERCISES · 5 TRACKED" subtitle
    /// on the right. Mirrors the History list's date-group header
    /// rhythm so the two surfaces share one vocabulary.
    private func sectionHeader(group: MuscleGroup, total: Int, tracked: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(group.accent.opacity(0.85))
                    .frame(width: 10, height: 2)
                Text(group.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))
                    .tracking(0.8)
            }
            Spacer()
            Text(sectionSubtitle(total: total, tracked: tracked))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.40))
                .tracking(0.6)
        }
        .padding(.horizontal, 4)
    }

    private func sectionSubtitle(total: Int, tracked: Int) -> String {
        let exercises = total == 1 ? "1 EXERCISE" : "\(total) EXERCISES"
        guard tracked > 0 else { return exercises }
        return "\(exercises) · \(tracked) TRACKED"
    }

    /// Row classifier: an exercise lifted within the last 14 days
    /// gets the rich journal-card treatment; everything else falls
    /// back to a compact chip. Mirrors the History list's
    /// rich-today / compact-earlier split, just keyed on the
    /// exercise's last-performed date instead of the session date.
    private func row(_ item: ExerciseCatalogItem) -> some View {
        let last = lastInstanceLookup[item.name.lowercased()]
        let isRecent: Bool = {
            guard let last else { return false }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: last.sessionDate),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? .max
            return days <= 14
        }()

        return Group {
            if let last, isRecent {
                richRow(item: item, last: last)
            } else {
                compactRow(item: item, last: last)
            }
        }
    }

    /// Detail screen receives no onPickAndDismiss callback — in the
    /// Library context there's nothing to "pick into," so the
    /// detail's bottom CTA hides automatically. Extracted so both
    /// row tiers share one navigation site + one context menu.
    private func rowLink<Content: View>(
        item: ExerciseCatalogItem,
        @ViewBuilder label: () -> Content
    ) -> some View {
        NavigationLink {
            ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                customExerciseTarget = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Rich row (recent lifts)

    /// Carved-glass journal card for exercises lifted in the last
    /// two weeks. Name + caps meta line on the left; the last
    /// session's heaviest set rendered as `CarvedVolumeText` on the
    /// right with a gold underline if the weight ties or beats the
    /// all-time best. A small relative-date caption sits below the
    /// carved digits so the row keeps the "when" anchored without
    /// a second number competing for attention.
    private func richRow(item: ExerciseCatalogItem, last: LastExerciseInstance) -> some View {
        let cornerRadius: CGFloat = 18
        return rowLink(item: item) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: item.equipment.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                    Text(metaCapsLine(item).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(0.9)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    CarvedVolumeText(
                        value: "\(WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false))×\(last.topReps)",
                        unit: "",
                        size: 22,
                        isPR: last.isAllTimeBest
                    )
                    Text(RelativeDate.short(last.sessionDate))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.5)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .glassCard(cornerRadius: cornerRadius)
            .topSpecularSheen(cornerRadius: cornerRadius, intensity: 0.08, height: 0.40)
            .glassRimBevel(cornerRadius: cornerRadius, outerWidth: 0.5, innerInset: 1.0)
        }
    }

    // MARK: Compact row (older history or untracked)

    /// Tighter chip for exercises with stale history (>14 days) or
    /// none at all. Same equipment icon + name + caps meta line on
    /// the left. The right side carries either a smaller carved
    /// weight×reps + relative date (older history) or a quiet dim
    /// default (untracked) so the row tier stays legible without
    /// pretending freshness it doesn't have.
    private func compactRow(item: ExerciseCatalogItem, last: LastExerciseInstance?) -> some View {
        let cornerRadius: CGFloat = 14
        return rowLink(item: item) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: item.equipment.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)
                    Text(metaCapsLine(item).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.8)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let last {
                    VStack(alignment: .trailing, spacing: 2) {
                        CarvedVolumeText(
                            value: "\(WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false))×\(last.topReps)",
                            unit: "",
                            size: 16,
                            isPR: last.isAllTimeBest
                        )
                        Text(RelativeDate.short(last.sessionDate))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(0.5)
                    }
                } else {
                    Text("\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(item.defaultReps) reps")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .glassChip(cornerRadius: cornerRadius)
            .glassRimBevel(cornerRadius: cornerRadius, outerWidth: 0.5, innerInset: 1.0)
        }
    }

    /// Monospaced-caps meta line shared by both row tiers — same
    /// vocabulary as History's muscle strip: "BARBELL · PUSH" or
    /// "DUMBBELL · ISOLATION".
    private func metaCapsLine(_ item: ExerciseCatalogItem) -> String {
        var parts: [String] = [item.equipment.displayName]
        if item.mechanic == .compound, let pattern = item.pattern {
            parts.append(pattern.displayName)
        } else if item.mechanic == .isolation {
            parts.append("Isolation")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(emptyMessage)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button {
                customExerciseTarget = .create
            } label: {
                Label("Create custom exercise", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .glassPill(tint: Tint.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private var emptyMessage: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        if equipmentFilter != nil {
            return "No exercises for that equipment."
        }
        return "Your catalog is empty."
    }

    // MARK: - Mutations

    private func delete(_ item: ExerciseCatalogItem) {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.soft()
    }
}

// MARK: - Template card

/// Reusable card for a row in the Templates list. Same visual as
/// before — extracted here so the file's two content views stay
/// purely about layout + state.
private struct TemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let used = template.lastUsedAt {
                    Text(Self.relative.localizedString(for: used, relativeTo: Date()))
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }

            Text("\(template.orderedExercises.count) exercises · \(template.totalPlannedSets) sets")
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.60))

            if !template.muscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(template.muscleGroups, id: \.self) { group in
                        Text(group.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(group.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(group.accent.opacity(0.16))
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

#Preview("Templates") {
    NavigationStack {
        LibraryScreen(appState: AppState())
            .navigationTitle("Library")
    }
    .preferredColorScheme(.dark)
}
