import SwiftUI

// MARK: - Name Section

struct CreateTemplateNameSection: View {
    @Binding var templateName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TEMPLATE NAME")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: $templateName)
                    .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle()
                            .fill(Color.vivoAccent)
                            .frame(height: 2),
                        alignment: .bottom
                    )

                Text("TIP: USE A/B VARIANTS FOR PROGRESSIVE OVERLOAD ROTATION")
                    .font(.vivoMono(VivoFont.monoTiny))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, VivoSpacing.sectionGap)
    }
}

// MARK: - Schedule Section

struct CreateTemplateScheduleSection: View {
    @Binding var selectedDays: Set<Int>
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCHEDULE \u{00B7} SELECT TRAINING DAYS")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            HStack(spacing: 4) {
                ForEach(0 ..< 7, id: \.self) { index in
                    dayPill(index: index)
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 14)
    }

    private func dayPill(index: Int) -> some View {
        let isSelected = selectedDays.contains(index)
        return Button { toggleDay(index) } label: {
            Text(dayLabels[index])
                .font(.vivoMono(VivoFont.monoCaption, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.vivoMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(isSelected ? Color.vivoAccent : Color.clear)
                )
                .overlay(
                    isSelected ? nil :
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .stroke(Color.vivoSurface, lineWidth: 1.5)
                )
        }
    }

    private func toggleDay(_ index: Int) {
        if selectedDays.contains(index) {
            selectedDays.remove(index)
        } else {
            selectedDays.insert(index)
        }
    }
}

// MARK: - Muscle Focus Section

struct CreateTemplateMuscleSection: View {
    @Binding var selectedMuscles: Set<String>
    private static let allMuscles = [
        "CHEST", "SHOULDERS", "TRICEPS", "BACK",
        "BICEPS", "QUADS", "HAMSTRINGS", "GLUTES",
        "CORE", "CALVES"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PRIMARY MUSCLE FOCUS")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            VivoFlowLayout(spacing: 6) {
                ForEach(Self.allMuscles, id: \.self) { muscle in
                    musclePill(muscle)
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 14)
    }

    private func musclePill(_ muscle: String) -> some View {
        let isSelected = selectedMuscles.contains(muscle)
        return Button { toggleMuscle(muscle) } label: {
            Text(muscle)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(isSelected ? Color.vivoAccent : Color.vivoSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(isSelected ? Color.vivoAccent.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .stroke(
                            isSelected ? Color.vivoAccent : Color.vivoSurface,
                            lineWidth: 1.5
                        )
                )
        }
    }

    private func toggleMuscle(_ muscle: String) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
    }
}

// MARK: - Notes Section

struct CreateTemplateNotesSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NOTES")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            TextEditor(text: $notes)
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoSecondary)
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(minHeight: 77)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.card)
                        .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.card)
                        .stroke(Color.vivoSurface, lineWidth: 1)
                )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 14)
    }
}

// MARK: - Summary

struct CreateTemplateSummary: View {
    let exerciseCount: Int
    let totalSets: Int
    let estMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TEMPLATE SUMMARY")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, VivoSpacing.itemGap)

            HStack(spacing: 0) {
                summaryColumn(
                    value: String(format: "%02d", exerciseCount),
                    label: "EXERCISES"
                )
                verticalDivider
                summaryColumn(value: "\(totalSets)", label: "TOTAL SETS")
                verticalDivider
                summaryColumn(value: "~\(estMinutes)m", label: "EST. TIME")
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }

    private func summaryColumn(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.vivoDisplay(VivoFont.headlineMD, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(VivoFont.monoMin))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 36)
    }
}

#Preview("Name") {
    CreateTemplateNameSection(templateName: .constant("Push Day A"))
        .background(Color.vivoBackground)
}

#Preview("Schedule") {
    CreateTemplateScheduleSection(selectedDays: .constant([0, 2]))
        .background(Color.vivoBackground)
}
