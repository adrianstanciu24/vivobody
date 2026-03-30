import SwiftUI

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State var templateName = "Upper Body Push B"
    @State var selectedDays: Set<Int> = [0, 2]
    @State var selectedMuscles: Set<String> = ["CHEST", "SHOULDERS", "TRICEPS"]
    @State var exercises: [TemplateExerciseItem] = TemplateExerciseItem.sampleData
    @State var notes = """
    Focus on mind-muscle connection for flys.
    Push B uses DB variants of Push A compounds.
    Alternate A/B each push day.
    """

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                createTemplateHeader(dismiss: dismiss)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        CreateTemplateNameSection(
                            templateName: $templateName
                        )
                        divider
                        CreateTemplateScheduleSection(
                            selectedDays: $selectedDays
                        )
                        divider
                        CreateTemplateMuscleSection(
                            selectedMuscles: $selectedMuscles
                        )
                        divider
                        CreateTemplateExerciseList(
                            exercises: $exercises
                        )
                        divider
                        CreateTemplateNotesSection(notes: $notes)
                        divider
                        CreateTemplateSummary(
                            exerciseCount: exercises.count,
                            totalSets: exercises.reduce(0) { $0 + $1.sets },
                            estMinutes: estimatedMinutes
                        )
                        saveButton
                        templateFooter
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var estimatedMinutes: Int {
        let setTime = 45
        var totalRestTime = 0
        var totalSetsVal = 0
        for exercise in exercises {
            totalSetsVal += exercise.sets
            let parts = exercise.restLabel.split(separator: ":")
            let seconds = parts.count == 2
                ? (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0)
                : 60
            totalRestTime += exercise.sets * seconds
        }
        return (totalSetsVal * setTime + totalRestTime) / 60
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }

    private var saveButton: some View {
        Button {
            dismiss()
        } label: {
            Text("SAVE TEMPLATE \u{2193}")
                .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
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

    private var templateFooter: some View {
        VivoFooter(
            line1: "VIVOBODY TEMPLATE EDITOR",
            line2: "NEW \u{00B7} UNSAVED DRAFT",
            line3: ""
        )
    }
}

// MARK: - Header

func createTemplateHeader(dismiss: DismissAction) -> some View {
    HStack {
        Button { dismiss() } label: {
            Text("\u{2190} CANCEL")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
        }
        Spacer()
        Text("NEW TEMPLATE")
            .font(.vivoMono(VivoFont.monoCaption))
            .tracking(VivoTracking.medium)
            .foregroundStyle(Color.vivoMuted)
        Spacer()
        Button { dismiss() } label: {
            Text("SAVE")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
        }
    }
    .padding(.horizontal, VivoSpacing.screenH)
    .padding(.vertical, 12)
}

// MARK: - Exercise Item

struct TemplateExerciseItem: Identifiable {
    let id = UUID()
    let name: String
    let primaryTag: String
    let secondaryTags: String
    var sets: Int
    var targetReps: Int
    var restLabel: String

    static let sampleData: [TemplateExerciseItem] = [
        TemplateExerciseItem(
            name: "Dumbbell Bench Press",
            primaryTag: "CHEST", secondaryTags: "COMPOUND \u{00B7} DUMBBELL",
            sets: 4, targetReps: 8, restLabel: "2:00"
        ),
        TemplateExerciseItem(
            name: "Incline Barbell Press",
            primaryTag: "CHEST", secondaryTags: "COMPOUND \u{00B7} BARBELL",
            sets: 3, targetReps: 10, restLabel: "2:00"
        ),
        TemplateExerciseItem(
            name: "Arnold Press",
            primaryTag: "SHOULDERS", secondaryTags: "COMPOUND \u{00B7} DUMBBELL",
            sets: 3, targetReps: 12, restLabel: "1:30"
        ),
        TemplateExerciseItem(
            name: "Pec Deck Fly",
            primaryTag: "CHEST", secondaryTags: "ISOLATION \u{00B7} MACHINE",
            sets: 3, targetReps: 12, restLabel: "1:00"
        ),
        TemplateExerciseItem(
            name: "Overhead Tri Extension",
            primaryTag: "TRICEPS", secondaryTags: "ISOLATION \u{00B7} CABLE",
            sets: 3, targetReps: 15, restLabel: "1:00"
        )
    ]
}

#Preview {
    CreateTemplateView()
}
