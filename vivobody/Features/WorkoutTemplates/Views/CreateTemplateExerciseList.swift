import SwiftUI

extension Int: @retroactive Identifiable {
    public var id: Int {
        self
    }
}

struct CreateTemplateExerciseList: View {
    @Binding var exercises: [TemplateExerciseItem]
    @State private var showPicker = false
    @State private var editingIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            exerciseRows
            addButton
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 14)
        .sheet(isPresented: $showPicker) {
            TemplateExercisePickerView(exercises: $exercises)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingIndex) { index in
            if exercises.indices.contains(index) {
                TemplateExerciseConfigView(
                    item: exercises[index]
                ) { updated in
                    exercises[index] = updated
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var sectionHeader: some View {
        Text("EXERCISES \u{00B7} \(String(format: "%02d", exercises.count)) ADDED")
            .font(.vivoMono(VivoFont.monoMicro))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .padding(.top, 16)
            .padding(.bottom, VivoSpacing.itemGap)
    }

    private var exerciseRows: some View {
        List {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                Button { editingIndex = index } label: {
                    TemplateExerciseRow(
                        exercise: exercise,
                        number: String(format: "%02d", index + 1)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        exercises.remove(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .frame(minHeight: CGFloat(exercises.count) * 92)
    }

    private var addButton: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoMono(VivoFont.body, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
                Text("ADD EXERCISE FROM LIBRARY")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(
                        Color.vivoSurface,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .padding(.top, 8)
    }
}

// MARK: - Exercise Row

struct TemplateExerciseRow: View {
    let exercise: TemplateExerciseItem
    let number: String

    var body: some View {
        HStack(spacing: 10) {
            numberLabel
            exerciseInfo
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(height: 92)
        .overlay(
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var numberLabel: some View {
        Text(number)
            .font(.vivoMono(VivoFont.monoSM))
            .foregroundStyle(Color.vivoMuted)
            .frame(width: 18)
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.body, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            HStack(spacing: 0) {
                Text(exercise.primaryTag)
                    .foregroundStyle(Color.vivoAccent)
                Text(" \u{00B7} \(exercise.secondaryTags)")
                    .foregroundStyle(Color.vivoSecondary)
            }
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.tight)
            .padding(.top, 2)

            HStack(spacing: 6) {
                infoPill(
                    bold: String(format: "%02d", exercise.sets),
                    label: " sets"
                )
                infoPill(
                    bold: String(format: "%02d", exercise.targetReps),
                    label: " reps"
                )
                restPill(label: "REST ", value: exercise.restLabel)
            }
            .padding(.top, 6)
        }
    }

    private func infoPill(
        bold: String, separator: String? = nil,
        bold2: String? = nil, label: String
    ) -> some View {
        HStack(spacing: 0) {
            Text(bold)
                .font(.vivoMono(VivoFont.monoTiny, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            if let separator {
                Text(separator)
                    .font(.vivoMono(VivoFont.monoTiny))
                    .foregroundStyle(Color.vivoSecondary)
            }
            if let bold2 {
                Text(bold2)
                    .font(.vivoMono(VivoFont.monoTiny, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
            }
            Text(label)
                .font(.vivoMono(VivoFont.monoTiny))
                .foregroundStyle(Color.vivoSecondary)
        }
        .tracking(VivoTracking.tight)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }

    private func restPill(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.vivoMono(VivoFont.monoTiny))
                .foregroundStyle(Color.vivoSecondary)
            Text(value)
                .font(.vivoMono(VivoFont.monoTiny, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
        .tracking(VivoTracking.tight)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

#Preview {
    CreateTemplateExerciseList(
        exercises: .constant(TemplateExerciseItem.sampleData)
    )
    .background(Color.vivoBackground)
}
