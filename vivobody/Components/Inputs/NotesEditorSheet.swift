//
//  NotesEditorSheet.swift
//  vivobody
//
//  Sheet-based plain-text editor for note fields (per-workout +
//  per-exercise). Driving the editor off a value-type `@State`
//  string buffer and committing the result on Save means SwiftUI
//  observation doesn't churn on every keystroke, and Cancel can
//  abandon edits cleanly without rewriting the model.
//
//  The same sheet handles both notes targets — caller passes a
//  title, optional placeholder, and the existing value; the closure
//  fires with the user's final text only on Save (never on Cancel
//  or swipe-down dismiss).
//

import SwiftUI

struct NotesEditorSheet: View {
    let title: String
    let placeholder: String
    let initialValue: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    init(
        title: String,
        placeholder: String = "Form cues, how it felt, plate setup…",
        initialValue: String,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialValue = initialValue
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $draft)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($isFocused)
                            .font(Typography.body)
                            .foregroundStyle(Ink.primary)
                            .tint(Tint.primary)
                            .frame(minHeight: 240)

                        // Hand-rolled placeholder. TextEditor's
                        // native one doesn't render on dark
                        // backgrounds without finicky overlays;
                        // overlaying a Text we hide on input is
                        // the reliably-styled iOS pattern.
                        if draft.isEmpty {
                            Text(placeholder)
                                .font(Typography.body)
                                .foregroundStyle(Ink.quaternary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        Haptics.soft()
                        onSave(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            draft = initialValue
            // Defer focus by one runloop so the sheet's transition
            // finishes before the keyboard rises — otherwise iOS
            // sometimes drops the focus during the animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
    }
}

#Preview {
    NotesEditorSheet(
        title: "Workout Notes",
        initialValue: "",
        onSave: { _ in }
    )
}
