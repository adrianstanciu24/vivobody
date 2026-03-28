import SwiftUI

struct LibraryExercise: Identifiable {
    let id: String
    let number: String
    let name: String
    let primaryTag: String
    let secondaryTags: String
    let bestWeight: String
    let bestLabel: String
}

struct ExerciseLibraryRow: View {
    let exercise: LibraryExercise

    var body: some View {
        HStack(spacing: 12) {
            Text(exercise.number)
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoPrimary)
                (Text(exercise.primaryTag)
                    .foregroundStyle(Color.vivoAccent)
                    + Text(" · \(exercise.secondaryTags)")
                    .foregroundStyle(Color.vivoMuted))
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(exercise.bestWeight)
                    .font(.vivoMono(14))
                    .foregroundStyle(Color.vivoPrimary)
                Text(exercise.bestLabel)
                    .font(.vivoMono(11))
                    .tracking(1)
                    .foregroundStyle(
                        exercise.bestLabel == "1RM PR"
                            ? Color.vivoGreen : Color.vivoSecondary
                    )
            }

            Text("›")
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(height: 72)
    }
}

// MARK: - Static Exercise Data

extension ExerciseLibraryView {
    static let chestExercises: [LibraryExercise] = [
        LibraryExercise(
            id: "c1",
            number: "01",
            name: "Barbell Bench Press",
            primaryTag: "COMPOUND",
            secondaryTags: "BARBELL · HORIZONTAL PUSH",
            bestWeight: "225 lb",
            bestLabel: "1RM PR"
        ),
        LibraryExercise(
            id: "c2",
            number: "02",
            name: "Incline Dumbbell Press",
            primaryTag: "COMPOUND",
            secondaryTags: "DUMBBELL · INCLINE",
            bestWeight: "80 lb",
            bestLabel: "1RM PR"
        ),
        LibraryExercise(
            id: "c3",
            number: "03",
            name: "Cable Fly",
            primaryTag: "ISOLATION",
            secondaryTags: "CABLE · HORIZONTAL",
            bestWeight: "35 lb",
            bestLabel: "BEST"
        ),
        LibraryExercise(
            id: "c4",
            number: "04",
            name: "Dips (Chest)",
            primaryTag: "COMPOUND",
            secondaryTags: "BODYWEIGHT · DECLINE",
            bestWeight: "BW+45",
            bestLabel: "BEST"
        ),
        LibraryExercise(
            id: "c5",
            number: "05",
            name: "Machine Chest Press",
            primaryTag: "COMPOUND",
            secondaryTags: "MACHINE · HORIZONTAL PUSH",
            bestWeight: "180 lb",
            bestLabel: "BEST"
        )
    ]

    static let backExercises: [LibraryExercise] = [
        LibraryExercise(
            id: "b1",
            number: "01",
            name: "Pull-Up",
            primaryTag: "COMPOUND",
            secondaryTags: "BODYWEIGHT · VERTICAL PULL",
            bestWeight: "BW+45",
            bestLabel: "1RM PR"
        ),
        LibraryExercise(
            id: "b2",
            number: "02",
            name: "Barbell Row",
            primaryTag: "COMPOUND",
            secondaryTags: "BARBELL · HORIZONTAL PULL",
            bestWeight: "205 lb",
            bestLabel: "1RM PR"
        ),
        LibraryExercise(
            id: "b3",
            number: "03",
            name: "Lat Pulldown",
            primaryTag: "COMPOUND",
            secondaryTags: "CABLE · VERTICAL PULL",
            bestWeight: "160 lb",
            bestLabel: "BEST"
        )
    ]
}

#Preview {
    VStack {
        ExerciseLibraryRow(exercise: ExerciseLibraryView.chestExercises[0])
        ExerciseLibraryRow(exercise: ExerciseLibraryView.chestExercises[1])
    }
    .padding(.horizontal, 24)
    .background(Color.vivoBackground)
}
