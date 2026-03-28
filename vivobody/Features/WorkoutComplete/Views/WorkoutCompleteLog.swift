import SwiftUI

// MARK: - Exercise Log

extension WorkoutCompleteView {
    struct LogExercise: Identifiable {
        let id: String
        let number: String
        let name: String
        let setCount: String
        let sets: [LogSet]
    }

    struct LogSet: Identifiable {
        let id: String
        let label: String
        let hasPR: Bool
    }

    static let logExercises: [LogExercise] = [
        LogExercise(id: "e1", number: "01", name: "Barbell Bench Press", setCount: "4 SETS", sets: [
            LogSet(id: "s1", label: "08×185", hasPR: false),
            LogSet(id: "s2", label: "08×185", hasPR: false),
            LogSet(id: "s3", label: "08×195", hasPR: false),
            LogSet(id: "s4", label: "06×205", hasPR: true)
        ]),
        LogExercise(id: "e2", number: "02", name: "Incline DB Press", setCount: "3 SETS", sets: [
            LogSet(id: "s5", label: "10×70", hasPR: false),
            LogSet(id: "s6", label: "10×75", hasPR: false),
            LogSet(id: "s7", label: "08×80", hasPR: true)
        ]),
        LogExercise(id: "e3", number: "03", name: "OHP", setCount: "3 SETS", sets: [
            LogSet(id: "s8", label: "08×115", hasPR: false),
            LogSet(id: "s9", label: "08×115", hasPR: false),
            LogSet(id: "s10", label: "06×125", hasPR: false)
        ]),
        LogExercise(id: "e4", number: "04", name: "Cable Fly", setCount: "4 SETS", sets: [
            LogSet(id: "s11", label: "12×30", hasPR: false),
            LogSet(id: "s12", label: "12×30", hasPR: false),
            LogSet(id: "s13", label: "12×35", hasPR: false),
            LogSet(id: "s14", label: "10×35", hasPR: false)
        ]),
        LogExercise(id: "e5", number: "05", name: "Lateral Raise", setCount: "4 SETS", sets: [
            LogSet(id: "s15", label: "15×20", hasPR: false),
            LogSet(id: "s16", label: "15×20", hasPR: false),
            LogSet(id: "s17", label: "12×25", hasPR: false),
            LogSet(id: "s18", label: "12×25", hasPR: false)
        ]),
        LogExercise(id: "e6", number: "06", name: "Tricep Pushdown", setCount: "3 SETS", sets: [
            LogSet(id: "s19", label: "12×50", hasPR: false),
            LogSet(id: "s20", label: "12×55", hasPR: false),
            LogSet(id: "s21", label: "10×60", hasPR: false)
        ])
    ]

    var exerciseLogSection: some View {
        VStack(spacing: 0) {
            Text("EXERCISE LOG")
                .font(.vivoMono(12))
                .tracking(2)
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Self.logExercises) { exercise in
                    logExerciseRow(exercise)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    func logExerciseRow(_ exercise: LogExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.number)
                    .font(.vivoMono(12))
                    .foregroundStyle(Color.vivoMuted)
                Text(exercise.name)
                    .font(.vivoDisplay(12))
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                Text(exercise.setCount)
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .padding(.top, 10)

            HStack(spacing: 6) {
                ForEach(exercise.sets) { set in
                    setPill(set)
                }
            }
            .padding(.bottom, 10)
        }
    }

    func setPill(_ set: LogSet) -> some View {
        let text = set.hasPR ? "\(set.label) PR" : set.label

        return Text(text)
            .font(.vivoMono(12))
            .foregroundStyle(set.hasPR ? Color.vivoGreen : Color.vivoSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        set.hasPR ? Color.vivoGreen : Color.vivoSurface,
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Action Buttons

extension WorkoutCompleteView {
    var actionButtons: some View {
        VStack(spacing: 8) {
            Button { onDismiss?() } label: {
                Text("SAVE & CLOSE")
                    .font(.vivoMono(12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .background(Color.vivoAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
            }

            Button {} label: {
                Text("SHARE RECEIPT")
                    .font(.vivoMono(12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.vivoSurface, lineWidth: 1.5)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Footer

extension WorkoutCompleteView {
    static let barcodeHeights: [CGFloat] = [
        20, 12, 20, 6, 18, 20, 5, 14, 20, 9, 20, 12, 7, 20, 11, 20
    ]

    var footerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                footerLine("SESSION #127 · UPPER PUSH A")
                footerLine("08:54 — 09:46 · MAR 18 2026")
                footerLine("SN: VIVO-2026-0318-127")
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(
                    Array(Self.barcodeHeights.enumerated()),
                    id: \.offset
                ) { _, height in
                    Rectangle()
                        .fill(Color.vivoMuted)
                        .frame(width: 1.5, height: height)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    func footerLine(_ text: String) -> some View {
        Text(text)
            .font(.vivoMono(7))
            .tracking(1.5)
            .foregroundStyle(Color.vivoMuted)
            .padding(.vertical, 0.5)
    }
}
