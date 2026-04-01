import SwiftUI

struct EditSetView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: SessionExercise
    let onSave: (Int, Int, Int) -> Void

    @State private var reps: Int
    @State private var load: Int
    @State private var rir: Int

    init(exercise: SessionExercise, onSave: @escaping (Int, Int, Int) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        let currentSet = exercise.sets.first(where: { !$0.completed })
        _reps = State(initialValue: currentSet?.reps ?? 8)
        _load = State(initialValue: currentSet?.weight ?? 0)
        _rir = State(initialValue: currentSet?.rir ?? 2)
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        exerciseInfo
                        sectionLabel("SET CONFIGURATION")
                        setConfiguration
                        divider
                        sectionLabel("REPS IN RESERVE")
                        rirControl
                        divider
                        logSetButton
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 16)
            .padding(.bottom, 10)
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
            Text("EDIT SET \(String(format: "%02d", exercise.currentSetNumber))")
                .font(.vivoMono(VivoFont.monoMD))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Button {
                onSave(reps, load, rir)
                dismiss()
            } label: {
                Text("LOG \u{2193}")
                    .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }
}

// MARK: - Exercise Info

private extension EditSetView {
    var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                "SET \(String(format: "%02d", exercise.currentSetNumber)) / \(String(format: "%02d", exercise.totalSets))"
            )
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)

            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
                .tracking(-1)

            tagsLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 4)
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

// MARK: - RIR Control

private extension EditSetView {
    var rirControl: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                VivoStepperButton(symbol: "\u{2212}") { rir = max(0, rir - 1) }

                HStack(spacing: 8) {
                    Text(String(format: "%02d", rir))
                        .font(.vivoDisplay(VivoFont.heroLG, weight: .bold))
                        .foregroundStyle(rirColor)

                    Text("REPS LEFT IN TANK")
                        .font(.vivoMono(VivoFont.monoSM))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                }

                Spacer()

                VivoStepperButton(symbol: "+") { rir = min(9, rir + 1) }
            }

            HStack(spacing: 4) {
                ForEach(0 ..< 10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(index <= rir ? rirBarColor(index) : Color.vivoSurface)
                        .frame(height: 6)
                }
            }

            HStack {
                Text("FAILURE")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
                Spacer()
                Text("EASY")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 10)
    }

    var rirColor: Color {
        if rir <= 1 { return Color.vivoAccent }
        if rir <= 3 { return Color.vivoYellow }
        return Color.vivoGreen
    }

    func rirBarColor(_ index: Int) -> Color {
        if index <= 1 { return Color.vivoAccent }
        if index <= 3 { return Color.vivoYellow }
        return Color.vivoGreen
    }
}

// MARK: - Log Set Button

private extension EditSetView {
    var logSetButton: some View {
        Button {
            onSave(reps, load, rir)
            dismiss()
        } label: {
            Text("LOG SET \(String(format: "%02d", exercise.currentSetNumber)) \u{2193}")
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
            SessionSet(order: 2, reps: 8, weight: 185, rir: 2),
            SessionSet(order: 3, reps: 8, weight: 185, rir: 1)
        ]
    )
    EditSetView(exercise: exercise) { _, _, _ in }
        .background(Color.vivoBackground)
}
