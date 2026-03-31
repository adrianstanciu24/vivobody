import SwiftUI

struct TemplateExerciseConfigView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onAdd: (TemplateExerciseItem) -> Void

    @State private var sets = 3
    @State private var targetReps = 10
    @State private var restMinutes = 2
    @State private var restSeconds = 0

    private var restLabel: String {
        String(format: "%d:%02d", restMinutes, restSeconds)
    }

    private var primaryTag: String {
        let parts = exercise.tags.components(separatedBy: " \u{00B7} ")
        return parts.first ?? exercise.tags
    }

    private var secondaryTags: String {
        let parts = exercise.tags.components(separatedBy: " \u{00B7} ")
        if parts.count > 1 {
            return parts.dropFirst().joined(separator: " \u{00B7} ")
        }
        return ""
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        exerciseHeader
                        divider
                        setsSection
                        divider
                        repsSection
                        divider
                        restSection
                        divider
                        summarySection
                        addButton
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
}

// MARK: - Header

private extension TemplateExerciseConfigView {
    var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Text("CONFIGURE EXERCISE")
                .font(.vivoMono(VivoFont.monoCaption))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("\u{2190} BACK")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }
}

// MARK: - Exercise Header

private extension TemplateExerciseConfigView {
    var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text(exercise.tags)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

// MARK: - Sets Section

private extension TemplateExerciseConfigView {
    var setsSection: some View {
        configRow(
            label: "SETS",
            subtitle: "Number of sets for this exercise"
        ) {
            HStack(spacing: 12) {
                VivoStepperButton(symbol: "\u{2212}") {
                    sets = max(1, sets - 1)
                }
                Text(String(format: "%02d", sets))
                    .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .frame(width: 44, alignment: .center)
                VivoStepperButton(symbol: "+") {
                    sets = min(10, sets + 1)
                }
            }
        }
    }
}

// MARK: - Reps Section

private extension TemplateExerciseConfigView {
    var repsSection: some View {
        configRow(
            label: "TARGET REPS",
            subtitle: "Target reps per set"
        ) {
            HStack(spacing: 12) {
                VivoStepperButton(symbol: "\u{2212}") {
                    targetReps = max(1, targetReps - 1)
                }
                Text(String(format: "%02d", targetReps))
                    .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .frame(width: 44, alignment: .center)
                VivoStepperButton(symbol: "+") {
                    targetReps = min(30, targetReps + 1)
                }
            }
        }
    }
}

// MARK: - Rest Section

private extension TemplateExerciseConfigView {
    var restSection: some View {
        configRow(
            label: "REST TIME",
            subtitle: "Rest between sets"
        ) {
            HStack(spacing: 12) {
                VivoStepperButton(symbol: "\u{2212}") {
                    decrementRest()
                }
                Text(restLabel)
                    .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .fixedSize()
                    .frame(minWidth: 80, alignment: .center)
                VivoStepperButton(symbol: "+") {
                    incrementRest()
                }
            }
        }
    }

    func decrementRest() {
        let totalSec = restMinutes * 60 + restSeconds - 15
        let clamped = max(15, totalSec)
        restMinutes = clamped / 60
        restSeconds = clamped % 60
    }

    func incrementRest() {
        let totalSec = restMinutes * 60 + restSeconds + 15
        let clamped = min(300, totalSec)
        restMinutes = clamped / 60
        restSeconds = clamped % 60
    }
}

// MARK: - Summary

private extension TemplateExerciseConfigView {
    var summarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PREVIEW")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            HStack(spacing: 6) {
                previewPill(
                    bold: String(format: "%02d", sets),
                    label: " sets"
                )
                previewPill(
                    bold: String(format: "%02d", targetReps),
                    label: " reps"
                )
                previewPill(label: "REST ", value: restLabel)
            }

            Text(
                "~\(sets * targetReps) total reps \u{00B7} ~\(estimatedTime) est."
            )
            .font(.vivoMono(VivoFont.monoDefault))
            .tracking(VivoTracking.tight)
            .foregroundStyle(Color.vivoMuted)
            .padding(.top, 8)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 14)
    }

    var estimatedTime: String {
        let setTimeSec = 45
        let restSec = restMinutes * 60 + restSeconds
        let total = sets * setTimeSec + (sets - 1) * restSec
        let mins = total / 60
        return "\(mins)m"
    }

    func previewPill(
        bold: String = "", separator: String? = nil,
        bold2: String? = nil, label: String, value: String? = nil
    ) -> some View {
        HStack(spacing: 0) {
            if let value {
                Text(label)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoSecondary)
                Text(value)
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
            } else {
                Text(bold)
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                if let separator {
                    Text(separator)
                        .font(.vivoMono(VivoFont.monoSM))
                        .foregroundStyle(Color.vivoSecondary)
                }
                if let bold2 {
                    Text(bold2)
                        .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                }
                Text(label)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoSecondary)
            }
        }
        .tracking(VivoTracking.tight)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
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

// MARK: - Add Button

private extension TemplateExerciseConfigView {
    var addButton: some View {
        Button {
            let item = TemplateExerciseItem(
                catalogID: exercise.catalogID,
                name: exercise.name,
                primaryTag: primaryTag,
                secondaryTags: secondaryTags,
                sets: sets,
                targetReps: targetReps,
                restLabel: restLabel
            )
            onAdd(item)
            dismiss()
        } label: {
            Text("ADD TO TEMPLATE \u{2193}")
                .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
                .tracking(VivoTracking.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                .shadow(
                    color: Color.vivoAccentShadow,
                    radius: 0, x: 0, y: 2
                )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }
}

// MARK: - Config Row Helper

private extension TemplateExerciseConfigView {
    func configRow(
        label: String,
        subtitle: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, 4)

            Text(subtitle)
                .font(.vivoMono(VivoFont.monoDefault))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
                .padding(.bottom, 14)

            HStack {
                Spacer()
                content()
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }
}

#Preview {
    TemplateExerciseConfigView(
        exercise: Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: "QUADS",
            secondaryTags: "BILATERAL SQUAT \u{00B7} BILATERAL"
        )
    ) { _ in }
}
