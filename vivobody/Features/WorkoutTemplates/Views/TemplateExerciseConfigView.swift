import SwiftUI

struct TemplateExerciseConfigView: View {
    @Environment(\.dismiss) private var dismiss
    let catalogID: String
    let exerciseName: String
    let tags: String
    let isEditing: Bool
    let onSave: (TemplateExerciseItem) -> Void

    @State private var sets: Int
    @State private var targetReps: Int
    @State private var restMinutes: Int
    @State private var restSeconds: Int

    init(exercise: Exercise, onAdd: @escaping (TemplateExerciseItem) -> Void) {
        catalogID = exercise.catalogID
        exerciseName = exercise.name
        tags = exercise.tags
        isEditing = false
        onSave = onAdd
        _sets = State(initialValue: 3)
        _targetReps = State(initialValue: 10)
        _restMinutes = State(initialValue: 2)
        _restSeconds = State(initialValue: 0)
    }

    init(item: TemplateExerciseItem, onUpdate: @escaping (TemplateExerciseItem) -> Void) {
        catalogID = item.catalogID
        exerciseName = item.name
        let combined = item.secondaryTags.isEmpty
            ? item.primaryTag
            : "\(item.primaryTag) \u{00B7} \(item.secondaryTags)"
        tags = combined
        isEditing = true
        onSave = onUpdate
        _sets = State(initialValue: item.sets)
        _targetReps = State(initialValue: item.targetReps)
        let parts = item.restLabel.split(separator: ":")
        let mins = parts.count == 2 ? Int(parts[0]) ?? 2 : 2
        let secs = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        _restMinutes = State(initialValue: mins)
        _restSeconds = State(initialValue: secs)
    }

    private var restLabel: String {
        String(format: "%d:%02d", restMinutes, restSeconds)
    }

    private var primaryTag: String {
        let parts = tags.components(separatedBy: " \u{00B7} ")
        return parts.first ?? tags
    }

    private var secondaryTags: String {
        let parts = tags.components(separatedBy: " \u{00B7} ")
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
            Text(isEditing ? "EDIT EXERCISE" : "CONFIGURE EXERCISE")
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
            Text(exerciseName)
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text(tags)
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
                catalogID: catalogID,
                name: exerciseName,
                primaryTag: primaryTag,
                secondaryTags: secondaryTags,
                sets: sets,
                targetReps: targetReps,
                restLabel: restLabel
            )
            onSave(item)
            dismiss()
        } label: {
            Text(isEditing ? "SAVE CHANGES \u{2193}" : "ADD TO TEMPLATE \u{2193}")
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
