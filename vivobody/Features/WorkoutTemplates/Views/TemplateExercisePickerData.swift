import Foundation

extension TemplateExercisePickerView {
    static let recentPicks: [PickerExercise] = [
        PickerExercise(
            id: "tr1", number: "01",
            name: "Barbell Bench Press",
            tags: "CHEST \u{00B7} COMPOUND",
            detail: "LAST: 185 LB \u{00D7} 08"
        ),
        PickerExercise(
            id: "tr2", number: "02",
            name: "Barbell Squat",
            tags: "LEGS \u{00B7} COMPOUND",
            detail: "LAST: 275 LB \u{00D7} 05"
        ),
        PickerExercise(
            id: "tr3", number: "03",
            name: "Pull-Up",
            tags: "BACK \u{00B7} COMPOUND",
            detail: "LAST: BW+25 \u{00D7} 08"
        )
    ]

    static let chestExercises: [PickerExercise] = [
        PickerExercise(
            id: "tc1", number: "01",
            name: "Barbell Bench Press",
            tags: "COMPOUND \u{00B7} BARBELL",
            detail: ""
        ),
        PickerExercise(
            id: "tc2", number: "02",
            name: "Incline Dumbbell Press",
            tags: "COMPOUND \u{00B7} DUMBBELL",
            detail: ""
        ),
        PickerExercise(
            id: "tc3", number: "03",
            name: "Cable Fly",
            tags: "ISOLATION \u{00B7} CABLE",
            detail: ""
        ),
        PickerExercise(
            id: "tc4", number: "04",
            name: "Dips (Chest)",
            tags: "COMPOUND \u{00B7} BODYWEIGHT",
            detail: ""
        ),
        PickerExercise(
            id: "tc5", number: "05",
            name: "Pec Deck Fly",
            tags: "ISOLATION \u{00B7} MACHINE",
            detail: ""
        )
    ]

    static let backExercises: [PickerExercise] = [
        PickerExercise(
            id: "tb1", number: "01",
            name: "Pull-Up",
            tags: "COMPOUND \u{00B7} BODYWEIGHT",
            detail: ""
        ),
        PickerExercise(
            id: "tb2", number: "02",
            name: "Barbell Row",
            tags: "COMPOUND \u{00B7} BARBELL",
            detail: ""
        ),
        PickerExercise(
            id: "tb3", number: "03",
            name: "Lat Pulldown",
            tags: "COMPOUND \u{00B7} CABLE",
            detail: ""
        ),
        PickerExercise(
            id: "tb4", number: "04",
            name: "Seated Cable Row",
            tags: "COMPOUND \u{00B7} CABLE",
            detail: ""
        )
    ]

    static let legExercises: [PickerExercise] = [
        PickerExercise(
            id: "tl1", number: "01",
            name: "Back Squat",
            tags: "COMPOUND \u{00B7} BARBELL",
            detail: ""
        ),
        PickerExercise(
            id: "tl2", number: "02",
            name: "Romanian Deadlift",
            tags: "COMPOUND \u{00B7} BARBELL",
            detail: ""
        ),
        PickerExercise(
            id: "tl3", number: "03",
            name: "Leg Press",
            tags: "COMPOUND \u{00B7} MACHINE",
            detail: ""
        )
    ]

    static let shoulderExercises: [PickerExercise] = [
        PickerExercise(
            id: "ts1", number: "01",
            name: "Overhead Press",
            tags: "COMPOUND \u{00B7} BARBELL",
            detail: ""
        ),
        PickerExercise(
            id: "ts2", number: "02",
            name: "Arnold Press",
            tags: "COMPOUND \u{00B7} DUMBBELL",
            detail: ""
        ),
        PickerExercise(
            id: "ts3", number: "03",
            name: "Lateral Raise",
            tags: "ISOLATION \u{00B7} DUMBBELL",
            detail: ""
        )
    ]
}
