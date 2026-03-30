import Foundation

struct PickerExercise: Identifiable {
    let id: String
    let number: String
    let name: String
    let tags: String
    let detail: String
}

extension ExercisePickerView {
    static let recentPicks: [PickerExercise] = [
        PickerExercise(
            id: "r1", number: "01",
            name: "Barbell Bench Press",
            tags: "CHEST · COMPOUND",
            detail: "LAST: 185 LB × 08"
        ),
        PickerExercise(
            id: "r2", number: "02",
            name: "Barbell Squat",
            tags: "LEGS · COMPOUND",
            detail: "LAST: 275 LB × 05"
        ),
        PickerExercise(
            id: "r3", number: "03",
            name: "Pull-Up",
            tags: "BACK · COMPOUND",
            detail: "LAST: BW+25 × 08"
        )
    ]

    static let chestExercises: [PickerExercise] = [
        PickerExercise(
            id: "c1", number: "01",
            name: "Barbell Bench Press",
            tags: "COMPOUND · BARBELL · HORIZONTAL PUSH",
            detail: ""
        ),
        PickerExercise(
            id: "c2", number: "02",
            name: "Incline Dumbbell Press",
            tags: "COMPOUND · DUMBBELL · INCLINE",
            detail: ""
        ),
        PickerExercise(
            id: "c3", number: "03",
            name: "Cable Fly",
            tags: "ISOLATION · CABLE · HORIZONTAL",
            detail: ""
        ),
        PickerExercise(
            id: "c4", number: "04",
            name: "Dips (Chest)",
            tags: "COMPOUND · BODYWEIGHT · DECLINE",
            detail: ""
        )
    ]

    static let backExercises: [PickerExercise] = [
        PickerExercise(
            id: "b1", number: "01",
            name: "Pull-Up",
            tags: "COMPOUND · BODYWEIGHT · VERTICAL PULL",
            detail: ""
        ),
        PickerExercise(
            id: "b2", number: "02",
            name: "Barbell Row",
            tags: "COMPOUND · BARBELL · HORIZONTAL PULL",
            detail: ""
        ),
        PickerExercise(
            id: "b3", number: "03",
            name: "Lat Pulldown",
            tags: "COMPOUND · CABLE · VERTICAL PULL",
            detail: ""
        )
    ]

    static let legExercises: [PickerExercise] = [
        PickerExercise(
            id: "l1", number: "01",
            name: "Back Squat",
            tags: "COMPOUND · BARBELL · QUAD DOMINANT",
            detail: ""
        ),
        PickerExercise(
            id: "l2", number: "02",
            name: "Romanian Deadlift",
            tags: "COMPOUND · BARBELL · HIP HINGE",
            detail: ""
        ),
        PickerExercise(
            id: "l3", number: "03",
            name: "Leg Press",
            tags: "COMPOUND · MACHINE · QUAD DOMINANT",
            detail: ""
        )
    ]
}
