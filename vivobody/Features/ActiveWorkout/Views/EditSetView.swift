import SwiftUI

struct EditSetView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: SessionExercise
    let onSave: (Int, SetValues) -> Void

    @State var selectedSetIndex: Int
    @State var reps: Int
    @State var load: Int
    @State var rir: Int
    @State var rom: String
    @State var tempo: String
    @State var grip: String
    @State var stance: String
    @State var showAdvanced = false

    private var selectedSet: SessionSet {
        exercise.sets[selectedSetIndex]
    }

    private var isCompletedSet: Bool {
        selectedSet.completed
    }

    init(
        exercise: SessionExercise,
        initialSetIndex: Int? = nil,
        onSave: @escaping (Int, SetValues) -> Void
    ) {
        self.exercise = exercise
        self.onSave = onSave
        let startIndex = initialSetIndex
            ?? exercise.sets.firstIndex(where: { !$0.completed })
            ?? 0
        _selectedSetIndex = State(initialValue: startIndex)
        let set = exercise.sets[startIndex]
        _reps = State(initialValue: set.reps)
        _load = State(initialValue: set.weight)
        _rir = State(initialValue: set.rir)
        _rom = State(initialValue: set.rom)
        _tempo = State(initialValue: set.tempo)
        _grip = State(initialValue: set.grip)
        _stance = State(initialValue: set.stance)
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        exerciseInfo
                        setPicker
                        sectionLabel("SET CONFIGURATION")
                        setConfiguration
                        divider
                        sectionLabel("REPS IN RESERVE")
                        rirControl
                        divider
                        advancedToggle
                        if showAdvanced {
                            advancedOptions
                            divider
                        }
                        saveButton
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationDetents(showAdvanced ? [.large] : [.fraction(0.7), .large])
        .presentationDragIndicator(.hidden)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }

    private func saveCurrentSet() {
        let values = SetValues(
            reps: reps, weight: load, rir: rir,
            rom: rom, tempo: tempo, grip: grip, stance: stance
        )
        onSave(selectedSetIndex, values)
        dismiss()
    }

    private func loadSet(at index: Int) {
        selectedSetIndex = index
        let set = exercise.sets[index]
        reps = set.reps
        load = set.weight
        rir = set.rir
        rom = set.rom
        tempo = set.tempo
        grip = set.grip
        stance = set.stance
    }
}

// MARK: - Header

private extension EditSetView {
    var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(VivoFont.monoMD))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Text("EDIT SET \(String(format: "%02d", selectedSet.order))")
                .font(.vivoMono(VivoFont.monoMD))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Button { saveCurrentSet() } label: {
                Text(isCompletedSet ? "SAVE" : "LOG \u{2193}")
                    .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }
}

// MARK: - Set Picker

private extension EditSetView {
    var setPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    let isSelected = index == selectedSetIndex
                    Button { loadSet(at: index) } label: {
                        Text("SET \(String(format: "%02d", set.order))")
                            .font(.vivoMono(VivoFont.monoSM, weight: isSelected ? .bold : .regular))
                            .tracking(VivoTracking.tight)
                            .foregroundStyle(pillForeground(isSelected: isSelected, isCompleted: set.completed))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(pillBackground(isSelected: isSelected, isCompleted: set.completed))
                            .clipShape(RoundedRectangle(cornerRadius: VivoRadius.pill))
                            .overlay(
                                RoundedRectangle(cornerRadius: VivoRadius.pill)
                                    .stroke(
                                        pillBorder(isSelected: isSelected, isCompleted: set.completed),
                                        lineWidth: 1.5
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
        .padding(.bottom, 8)
    }

    func pillForeground(isSelected: Bool, isCompleted: Bool) -> Color {
        if isSelected { return .white }
        if isCompleted { return Color.vivoGreen }
        return Color.vivoMuted
    }

    func pillBackground(isSelected: Bool, isCompleted: Bool) -> Color {
        if isSelected, isCompleted { return Color.vivoGreen }
        if isSelected { return Color.vivoAccent }
        return .clear
    }

    func pillBorder(isSelected: Bool, isCompleted: Bool) -> Color {
        if isSelected { return .clear }
        if isCompleted { return Color.vivoGreen.opacity(0.4) }
        return Color.vivoSurface
    }
}

// MARK: - Exercise Info

private extension EditSetView {
    var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
                .tracking(-1)

            tagsLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    var tagsLabel: some View {
        let tagParts = exercise.tags.components(separatedBy: " \u{00B7} ")
        return HStack(spacing: 0) {
            if let first = tagParts.first {
                Text(first)
                    .foregroundStyle(Color.vivoAccent)
            }
            if tagParts.count > 1 {
                Text(" \u{00B7} " + tagParts.dropFirst().joined(separator: " \u{00B7} "))
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .font(.vivoMono(VivoFont.monoSM))
        .tracking(VivoTracking.normal)
    }
}

// MARK: - Set Configuration

private extension EditSetView {
    var setConfiguration: some View {
        HStack(spacing: 0) {
            stepperColumn(value: String(format: "%02d", reps), label: "REPS") {
                reps = max(1, reps - 1)
            } onPlus: {
                reps += 1
            }

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1, height: 158)

            stepperColumn(
                value: "\(load)",
                label: "LOAD",
                suffix: "lb"
            ) {
                load = max(0, load - 5)
            } onPlus: {
                load += 5
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }

    func stepperColumn(
        value: String,
        label: String,
        suffix: String? = nil,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.vivoDisplay(VivoFont.heroXL, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                if let suffix {
                    Text(suffix)
                        .font(.vivoMono(VivoFont.monoDefault))
                        .foregroundStyle(Color.vivoMuted)
                        .offset(y: 12)
                }
            }

            Text(label)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)

            HStack(spacing: 12) {
                VivoStepperButton(symbol: "\u{2212}", action: onMinus)
                VivoStepperButton(symbol: "+", action: onPlus)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Save / Log Button

extension EditSetView {
    var saveButton: some View {
        Button { saveCurrentSet() } label: {
            Text(isCompletedSet
                ? "SAVE SET \(String(format: "%02d", selectedSet.order))"
                : "LOG SET \(String(format: "%02d", selectedSet.order)) \u{2193}")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }
}

// MARK: - Preview

#Preview {
    let exercise = SessionExercise(
        catalogID: "front_squat",
        name: "Front Squat",
        primaryTag: "QUADS",
        secondaryTags: "BILATERAL SQUAT \u{00B7} BILATERAL",
        muscleGroup: .legs,
        sets: [
            SessionSet(order: 1, reps: 8, weight: 185, rir: 3, completed: true),
            SessionSet(order: 2, reps: 8, weight: 185, rir: 2, completed: true),
            SessionSet(order: 3, reps: 8, weight: 185, rir: 1)
        ]
    )
    EditSetView(exercise: exercise) { _, _ in }
        .background(Color.vivoBackground)
}
