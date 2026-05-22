//
//  LibraryScreen.swift
//  workapp
//
//  Lists the user's saved workout templates. Each card summarises a
//  template (name, exercise count, muscle-group capsules); tapping
//  pushes to the detail/start screen, long-press offers Edit/Delete.
//  The nav-bar "+" opens the TemplateEditor in create mode; the
//  context menu and detail-screen overflow open it in edit mode.
//
//  Templates live in SwiftData via @Query; mutations propagate
//  automatically. New templates land at the bottom of the list.
//

import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder)])
    private var templates: [WorkoutTemplate]

    /// When non-nil, the destructive confirmation alert is showing
    /// for that template.
    @State private var deletingTemplate: WorkoutTemplate? = nil

    /// When non-nil, the editor sheet is showing (either for a new
    /// template or one being edited).
    @State private var editorTarget: TemplateEditorTarget? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if templates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
        .toolbar { toolbar }
        .sheet(item: $editorTarget) { target in
            TemplateEditorScreen(target: target)
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                editorTarget = .new(sortOrder: templates.count)
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("New template")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.30))

            Text("NO TEMPLATES YET")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            Text("Build a reusable workout — pick exercises, set target reps and weight. Start any time from here.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                editorTarget = .new(sortOrder: 0)
            } label: {
                Text("Create Template")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    // MARK: - List

    private var templateList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(templates) { template in
                    NavigationLink {
                        TemplateDetailScreen(
                            template: template,
                            appState: appState,
                            onEdit: { editorTarget = .edit(template) },
                            onDelete: { deletingTemplate = template }
                        )
                    } label: {
                        TemplateCard(template: template)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editorTarget = .edit(template)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingTemplate = template
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
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
        // Re-pack sortOrder so the next "+" sits at the right index.
        for (i, t) in templates.enumerated() {
            t.sortOrder = i
        }
        try? modelContext.save()
        Haptics.soft()
        deletingTemplate = nil
    }
}

// MARK: - Template card

private struct TemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let used = template.lastUsedAt {
                    Text(Self.relative.localizedString(for: used, relativeTo: Date()).uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            Text("\(template.orderedExercises.count) exercises  ·  \(template.totalPlannedSets) sets")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            if !template.muscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(template.muscleGroups, id: \.self) { group in
                        Text(group.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(group.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(group.accent.opacity(0.16))
                            )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

#Preview("Empty") {
    NavigationStack {
        LibraryScreen(appState: AppState())
            .navigationTitle("Library")
    }
    .preferredColorScheme(.dark)
}
