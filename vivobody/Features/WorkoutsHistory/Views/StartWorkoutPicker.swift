import SwiftData
import SwiftUI

struct StartWorkoutPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        emptyOption
                        divider
                        templatesList
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} CANCEL")
                    .font(.vivoMono(VivoFont.monoMD))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Text("START WORKOUT")
                .font(.vivoMono(VivoFont.monoMD))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Color.clear.frame(width: 60)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    private var emptyOption: some View {
        Button {
            session?.start()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text("+")
                    .font(.vivoDisplay(VivoFont.headlineSM, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
                    .frame(width: 36, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                            .fill(Color.vivoAccent.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("EMPTY WORKOUT")
                        .font(.vivoDisplay(VivoFont.sectionTitle, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                    Text("Start from scratch — add exercises as you go")
                        .font(.vivoMono(VivoFont.monoSM))
                        .foregroundStyle(Color.vivoMuted)
                }

                Spacer()

                Text("\u{2192}")
                    .font(.vivoDisplay(VivoFont.headlineSM))
                    .foregroundStyle(Color.vivoMuted)
            }
            .padding(VivoSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoAccent, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }

    @ViewBuilder
    private var templatesList: some View {
        if templates.isEmpty {
            emptyTemplatesHint
        } else {
            templatesSection
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FROM TEMPLATE")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ForEach(templates) { template in
                templateRow(template)
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            session?.start(from: template)
            dismiss()
        } label: {
            TemplateCardView(template: template)
        }
        .buttonStyle(.plain)
    }

    private var emptyTemplatesHint: some View {
        Text("No templates yet — create one from the Templates tab.")
            .font(.vivoMono(VivoFont.monoSM))
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 16)
    }
}

#Preview {
    StartWorkoutPicker()
        .environment(WorkoutSession())
        .modelContainer(
            for: [
                WorkoutTemplate.self, TemplateExercise.self,
                Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self
            ],
            inMemory: true
        )
}
