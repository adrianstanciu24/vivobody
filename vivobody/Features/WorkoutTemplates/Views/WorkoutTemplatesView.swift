import SwiftData
import SwiftUI

struct WorkoutTemplatesView: View {
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    @State private var showCreate = false

    var body: some View {
        if templates.isEmpty {
            WorkoutTemplatesEmptyState {
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
        }
    }

    private var templateList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(templates) { template in
                    templateRow(template)
                    divider
                }

                createButton
                VivoFooter()
            }
            .padding(.bottom, 32)
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name.uppercased())
                    .font(.vivoDisplay(VivoFont.body, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)

                Text(
                    "\(template.exercises.count) EXERCISES · USED \(template.timesUsed)×"
                )
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Text("›")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .frame(height: 72)
    }

    private var createButton: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoAccent)
                Text("CREATE TEMPLATE")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoSurface, lineWidth: 1.5)
            )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
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
