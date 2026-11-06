//
//  TemplateLiveEditorScreen.swift
//  vivobody
//
//  The template editor beside the Library list in regular width. It is a
//  column root rather than a modal, so it has no Save or Cancel: each change
//  to the draft writes through to the template at once, as the exercise
//  detail beside it does.
//

import SwiftData
import SwiftUI

struct TemplateLiveEditorScreen: View {
    let template: WorkoutTemplate

    @Environment(\.modelContext) private var modelContext

    @State private var draft: TemplateDraft
    /// The draft as last written. Hydrating a draft mints new exercise IDs,
    /// so comparing against this rather than a fresh hydration keeps a
    /// rollback resync from rewriting every exercise.
    @State private var savedDraft: TemplateDraft
    @State private var saveError: SaveErrorBox? = nil

    init(template: WorkoutTemplate) {
        self.template = template
        let draft = TemplateDraft(editing: template)
        _draft = State(wrappedValue: draft)
        _savedDraft = State(wrappedValue: draft)
    }

    var body: some View {
        TemplateEditorForm(draft: $draft, focusesNameOnAppear: false)
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft) { _, updated in
                persist(updated)
            }
            .saveErrorAlert($saveError)
    }

    /// A blank name is not written, so clearing the field to retype it
    /// keeps the stored name.
    private func persist(_ updated: TemplateDraft) {
        guard updated != savedDraft else { return }
        let name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != template.name {
            template.name = name
        }
        if updated.scheduledWeekdays != savedDraft.scheduledWeekdays {
            template.scheduledWeekdays = updated.scheduledWeekdays
        }
        if updated.exercises != savedDraft.exercises {
            updated.replaceExercises(of: template, in: modelContext)
        }
        guard modelContext.hasChanges else {
            savedDraft = updated
            return
        }
        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
            SpotlightIndexer.index(template)
            savedDraft = updated
        } catch {
            saveError = SaveErrorBox(error)
            let restored = TemplateDraft(editing: template)
            savedDraft = restored
            draft = restored
        }
    }
}
