import SwiftData
import SwiftUI

struct WorkoutTemplatesView: View {
    @Environment(PersistenceController.self) private var persistence
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    @State private var showCreate = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var templateToDelete: WorkoutTemplate?

    var body: some View {
        if templates.isEmpty {
            WorkoutTemplatesEmptyStateView {
                showCreate = true
            }
            .sheet(isPresented: $showCreate) {
                CreateTemplateView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        } else {
            templateList
                .sheet(isPresented: $showCreate) {
                    CreateTemplateView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                }
                .sheet(item: $editingTemplate) { template in
                    CreateTemplateView(template: template)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                }
        }
    }

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                templateRow(template)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            templateToDelete = template
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            createButton
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            VivoFooter()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .alert("Delete Template?", isPresented: Binding(
            get: { templateToDelete != nil },
            set: { if !$0 { templateToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { templateToDelete = nil }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    persistence.delete(template)
                }
                templateToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button { editingTemplate = template } label: {
            TemplateCardView(template: template)
        }
        .buttonStyle(.plain)
    }

    private var createButton: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
                Text("CREATE TEMPLATE")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(
                        Color.vivoSurface,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 12)
    }
}

#Preview {
    WorkoutTemplatesView()
        .background(Color.vivoBackground)
        .modelContainer(
            for: [
                WorkoutTemplate.self, TemplateExercise.self,
                Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self
            ],
            inMemory: true
        )
}
