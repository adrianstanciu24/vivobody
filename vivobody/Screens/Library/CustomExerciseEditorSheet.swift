//
//  CustomExerciseEditorSheet.swift
//  vivobody
//
//  Root orchestration for creating, editing, or duplicating a catalog entry.
//  It owns SwiftData, presentation, save failure, focus, and the muscle
//  editor sheet; focused sections render and edit the value-type
//  CatalogDraft, with single choices in native menu pickers.
//

import SwiftData
import SwiftUI
import VivoKit

enum CatalogEditorTarget: Identifiable {
    case create
    case edit(ExerciseCatalogItem)
    /// Fork a bundled exercise into a fully editable user-created
    /// copy. The copy keeps the source's semantics but gets a fresh
    /// identity, so logged history stays with the bundled original.
    case duplicate(ExerciseCatalogItem)

    var id: String {
        switch self {
        case .create: "create"
        case let .edit(item): "edit-\(item.id)"
        case let .duplicate(item): "duplicate-\(item.id)"
        }
    }
}

struct CustomExerciseEditorSheet: View {
    let target: CatalogEditorTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Used only to enforce the same globally-unique canonical-name /
    /// alias namespace as the bundled catalog. The edited item is
    /// excluded from its own collision check.
    @Query private var catalogItems: [ExerciseCatalogItem]

    @State private var draft: CatalogDraft
    /// Scrub increments are preferences, not catalog data: they stay out of
    /// the draft and are written to UserDefaults only after a committed save.
    @State private var scrubSteps: ExerciseScrubSteps

    @State private var saveError: SaveErrorBox? = nil
    @State private var isMuscleEditorPresented = false
    @State private var showsValidationErrors = false
    /// One-shot guard for the duplicate name prefill — onAppear fires
    /// again when child sheets dismiss, and the user's typed name
    /// must never be overwritten after the first resolution.
    @State private var didResolveDuplicateName = false

    @FocusState private var nameFieldFocused: Bool

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    init(target: CatalogEditorTarget) {
        self.target = target
        switch target {
        case .create:
            _draft = State(initialValue: CatalogDraft.empty)
            _scrubSteps = State(initialValue: ExerciseScrubSteps())
        case let .edit(item):
            _draft = State(initialValue: CatalogDraft(from: item))
            _scrubSteps = State(initialValue: Self.storedSteps(for: item))
        case let .duplicate(item):
            _draft = State(initialValue: CatalogDraft(
                duplicating: item,
                defaultWeight: item.defaultWeightSeed
            ))
            _scrubSteps = State(initialValue: Self.storedSteps(for: item))
        }
    }

    private static func storedSteps(for item: ExerciseCatalogItem) -> ExerciseScrubSteps {
        ExerciseScrubStepStore.load(catalogID: item.catalogID, catalogItemID: item.id)
    }

    private var isEditMode: Bool {
        if case .edit = target { return true }
        return false
    }

    /// Bundled records own a stable semantic identity. Users may tune
    /// logging defaults, but changing anatomy, mechanics, modality, or
    /// load interpretation in place would merge an unrelated movement
    /// into the bundled exercise's history key.
    private var isBundledEdit: Bool {
        guard case let .edit(item) = target else { return false }
        return item.catalogID != nil && !item.isUserCreated
    }

    /// The bundled exercise a duplicate draft was prefilled from.
    /// Drives the history-split note and the unique-name prefill.
    private var duplicateSource: ExerciseCatalogItem? {
        guard case let .duplicate(item) = target else { return nil }
        return item
    }

    private var editorTitle: String {
        if isBundledEdit { return "Exercise Defaults" }
        switch target {
        case .create: return "New Exercise"
        case .edit: return "Edit Exercise"
        case .duplicate: return "Duplicate Exercise"
        }
    }

    private var editedItemID: UUID? {
        guard case let .edit(item) = target else { return nil }
        return item.id
    }

    private var validation: CatalogDraftValidation {
        let occupiedSearchTerms = catalogItems
            .filter { $0.id != editedItemID }
            .flatMap { [$0.name] + $0.aliases }
        return CatalogDraftValidation(
            draft: draft,
            occupiedSearchTerms: occupiedSearchTerms
        )
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.section) {
                        if isBundledEdit {
                            bundledIdentitySummary
                            if draft.showsLoggingDefaults {
                                CustomExerciseDefaultsRow(
                                    draft: $draft,
                                    steps: $scrubSteps,
                                    unit: unit
                                )
                            }
                        } else {
                            if let source = duplicateSource {
                                duplicateOriginNote(source: source)
                            }
                            editorFields
                        }
                    }
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .screenBackground()
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            attemptSave(using: scrollProxy)
                        }
                        .bold()
                    }
                }
                .onAppear {
                    if !isBundledEdit {
                        draft.normalizeBandLoadForEditorPresentation()
                    }
                    if let source = duplicateSource, !didResolveDuplicateName {
                        didResolveDuplicateName = true
                        // One-shot prefill: resolve the "(Custom)" name
                        // against the live catalog. A direct fetch, not
                        // the @Query, which may not have delivered on
                        // first appear.
                        let catalog = (try? modelContext.fetch(
                            FetchDescriptor<ExerciseCatalogItem>()
                        )) ?? []
                        let taken = Set(catalog.flatMap { [$0.name] + $0.aliases })
                        draft.name = CatalogDraft.duplicateName(base: source.name, taken: taken)
                    }
                    if !isEditMode {
                        // Focus the name field for create-mode; the
                        // keyboard slides up immediately so the user can
                        // start typing without an extra tap.
                        nameFieldFocused = true
                    }
                }
            }
        }
        .sheet(isPresented: $isMuscleEditorPresented) {
            MuscleInvolvementEditorSheet(
                initialSnapshot: draft.muscleInvolvementSnapshot
            ) { snapshot in
                draft.muscleInvolvementSnapshot = snapshot
            }
        }
        .saveErrorAlert($saveError)
    }

    @ViewBuilder
    private var editorFields: some View {
        CustomExerciseBasicsSection(
            draft: $draft,
            validation: validation,
            showsValidationErrors: showsValidationErrors,
            nameFieldFocus: $nameFieldFocused,
            onPresentMuscleEditor: {
                nameFieldFocused = false
                isMuscleEditorPresented = true
            }
        )
        CustomExerciseClassificationSection(
            draft: $draft,
            validation: validation,
            showsValidationErrors: showsValidationErrors
        )
        CustomExerciseLoggingDefaultsSection(
            draft: $draft,
            steps: $scrubSteps,
            validation: validation,
            showsValidationErrors: showsValidationErrors,
            unit: unit
        )
        CustomExerciseSearchSection(
            draft: $draft,
            validation: validation,
            showsValidationErrors: showsValidationErrors
        )
    }

    private var bundledIdentitySummary: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(draft.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            if let execution = draft.execution {
                ExerciseInstructionSummary(execution: execution)
            }
            Text("Canonical mechanics, modality, load semantics, and muscle roles are locked so this exercise keeps one stable history identity.")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
        }
    }

    /// The one consequence of duplicating the form can't show: the
    /// copy gets a fresh identity, so logged history stays with the
    /// bundled original.
    private func duplicateOriginNote(source: ExerciseCatalogItem) -> some View {
        Text("Starts its own history. Past workouts stay with \(source.name).")
            .font(Typography.caption)
            .foregroundStyle(Ink.quaternary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func attemptSave(using scrollProxy: ScrollViewProxy) {
        guard validation.canSave else {
            showsValidationErrors = true
            Haptics.soft()

            guard let anchor = validation.firstInvalidAnchor else { return }
            if anchor == .name {
                nameFieldFocused = true
            } else {
                nameFieldFocused = false
            }

            if reduceMotion {
                scrollProxy.scrollTo(anchor, anchor: .center)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    scrollProxy.scrollTo(anchor, anchor: .center)
                }
            }
            return
        }

        save()
    }

    private func save() {
        guard validation.canSave else { return }
        do {
            let result = try CatalogMutationBoundary(context: modelContext).save(
                draft.mutationInput(using: validation),
                target: mutationTarget,
                unit: unit
            )
            if let item = result.savedItem {
                ExerciseScrubStepStore.store(
                    scrubSteps,
                    catalogID: item.catalogID,
                    catalogItemID: item.id
                )
            }
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.thunk()
        dismiss()
    }

    private var mutationTarget: CatalogMutationTarget {
        switch target {
        case .create:
            .create
        case let .edit(item):
            .edit(item: item)
        case let .duplicate(source):
            .duplicate(source: source)
        }
    }
}
