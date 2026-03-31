import SwiftData
import SwiftUI

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PersistenceController.self) private var persistence

    var existingTemplate: WorkoutTemplate?
    @State private var viewModel: CreateTemplateViewModel?

    @State var templateName: String
    @State var selectedDays: Set<Int>
    @State var selectedMuscles: Set<String>
    @State var exercises: [TemplateExerciseItem]
    @State var notes: String

    private var isEditing: Bool {
        existingTemplate != nil
    }

    init(template: WorkoutTemplate? = nil) {
        existingTemplate = template
        if let template {
            _templateName = State(initialValue: template.name)
            _selectedDays = State(initialValue: Set(template.scheduleDays))
            _selectedMuscles = State(
                initialValue: Set(template.muscleGroups.map { $0.displayName.uppercased() })
            )
            _exercises = State(
                initialValue: template.exercises
                    .sorted { $0.order < $1.order }
                    .map { ex in
                        let mins = ex.restSeconds / 60
                        let secs = ex.restSeconds % 60
                        return TemplateExerciseItem(
                            catalogID: ex.catalogID,
                            name: ex.name,
                            primaryTag: ex.primaryTag,
                            secondaryTags: ex.secondaryTags,
                            sets: ex.targetSets,
                            targetReps: ex.targetReps,
                            restLabel: String(format: "%d:%02d", mins, secs)
                        )
                    }
            )
            _notes = State(initialValue: template.notes)
        } else {
            _templateName = State(initialValue: "")
            _selectedDays = State(initialValue: [])
            _selectedMuscles = State(initialValue: [])
            _exercises = State(initialValue: [])
            _notes = State(initialValue: "")
        }
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                createTemplateHeader(
                    title: isEditing ? "EDIT TEMPLATE" : "NEW TEMPLATE",
                    dismiss: dismiss,
                    onSave: saveTemplate
                )
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
        .task {
            if viewModel == nil {
                viewModel = CreateTemplateViewModel(modelContext: persistence.modelContext)
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

    private func saveTemplate() {
        let draft = TemplateDraft(
            name: templateName,
            selectedMuscles: selectedMuscles,
            scheduleDays: selectedDays,
            notes: notes,
            exercises: exercises
        )
        viewModel?.save(existingTemplate: existingTemplate, draft: draft)
    }

    private var saveButton: some View {
        Button {
            saveTemplate()
            dismiss()
        } label: {
            Text(isEditing ? "UPDATE TEMPLATE \u{2193}" : "SAVE TEMPLATE \u{2193}")
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
            line2: isEditing ? "EDITING \u{00B7} \(templateName.uppercased())" : "NEW \u{00B7} UNSAVED DRAFT",
            line3: ""
        )
    }
}

// MARK: - Header

func createTemplateHeader(
    title: String = "NEW TEMPLATE",
    dismiss: DismissAction,
    onSave: @escaping () -> Void
) -> some View {
    HStack {
        Button { dismiss() } label: {
            Text("\u{2190} CANCEL")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
        }
        Spacer()
        Text(title)
            .font(.vivoMono(VivoFont.monoCaption))
            .tracking(VivoTracking.medium)
            .foregroundStyle(Color.vivoMuted)
        Spacer()
        Button {
            onSave()
            dismiss()
        } label: {
            Text("SAVE")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
        }
    }
    .padding(.horizontal, VivoSpacing.screenH)
    .padding(.vertical, 12)
}

// MARK: - Exercise Item

struct TemplateExerciseItem: Identifiable, Equatable {
    let id = UUID()
    let catalogID: String
    let name: String
    let primaryTag: String
    let secondaryTags: String
    var sets: Int
    var targetReps: Int
    var restLabel: String

    static let sampleData: [TemplateExerciseItem] = [
        TemplateExerciseItem(
            catalogID: "front_squat",
            name: "Front Squat",
            primaryTag: "QUADS", secondaryTags: "BILATERAL SQUAT \u{00B7} BILATERAL",
            sets: 4, targetReps: 8, restLabel: "2:00"
        ),
        TemplateExerciseItem(
            catalogID: "high_bar_back_squat",
            name: "High-Bar Back Squat",
            primaryTag: "QUADS", secondaryTags: "BILATERAL SQUAT \u{00B7} BILATERAL",
            sets: 3, targetReps: 10, restLabel: "2:00"
        ),
        TemplateExerciseItem(
            catalogID: "low_bar_back_squat",
            name: "Low-Bar Back Squat",
            primaryTag: "GLUTES", secondaryTags: "BILATERAL SQUAT \u{00B7} BILATERAL",
            sets: 3, targetReps: 12, restLabel: "1:30"
        ),
        TemplateExerciseItem(
            catalogID: "bulgarian_split_squat",
            name: "Bulgarian Split Squat",
            primaryTag: "QUADS", secondaryTags: "SPLIT SQUAT \u{00B7} UNILATERAL",
            sets: 3, targetReps: 12, restLabel: "1:00"
        ),
        TemplateExerciseItem(
            catalogID: "romanian_deadlift",
            name: "Romanian Deadlift",
            primaryTag: "GLUTES", secondaryTags: "HIP HINGE \u{00B7} BILATERAL",
            sets: 3, targetReps: 15, restLabel: "1:00"
        )
    ]
}

#Preview {
    CreateTemplateView()
        .withPersistence()
        .modelContainer(
            for: [WorkoutTemplate.self, TemplateExercise.self, Exercise.self],
            inMemory: true
        )
}
