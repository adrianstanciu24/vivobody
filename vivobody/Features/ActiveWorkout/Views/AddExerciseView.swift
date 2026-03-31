import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSession.self) private var session: WorkoutSession?

    let exercise: Exercise

    @State var reps = 8
    @State var load = 185
    @State var rir = 2
    @State var rom = "FULL"
    @State var tempo = "CONTROLLED"
    @State var grip = "NORMAL"
    @State var stance = "NORMAL"
    @State var loggedSets: [LoggedSet] = []

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
                        recentLoads
                        divider
                        sectionLabel("REPS IN RESERVE")
                        rirControl
                        divider
                        sectionLabel("RANGE OF MOTION")
                        VivoSegmentPicker(
                            options: ["PARTIAL", "FULL", "DEEP"],
                            selection: $rom
                        )
                        .padding(.horizontal, VivoSpacing.screenH)
                        sectionLabel("TEMPO")
                        VivoSegmentPicker(
                            options: ["EXPLOSIVE", "CONTROLLED", "SLOW", "PAUSED"],
                            selection: $tempo,
                            accentSelected: true
                        )
                        .padding(.horizontal, VivoSpacing.screenH)
                        sectionLabel("GRIP")
                        VivoSegmentPicker(
                            options: ["WIDE", "NORMAL", "NARROW"],
                            selection: $grip
                        )
                        .padding(.horizontal, VivoSpacing.screenH)
                        sectionLabel("STANCE")
                        VivoSegmentPicker(
                            options: ["WIDE", "NORMAL", "NARROW"],
                            selection: $stance
                        )
                        .padding(.horizontal, VivoSpacing.screenH)
                        divider
                        logSetButton
                        loggedSetsSection
                        footerInfo
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

private extension AddExerciseView {
    var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(VivoFont.monoMD))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Text("ADD EXERCISE")
                .font(.vivoMono(VivoFont.monoMD))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Button { saveAndDismiss() } label: {
                Text("SAVE")
                    .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                    .foregroundStyle(Color.vivoAccent)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    func saveAndDismiss() {
        let sets = loggedSets.enumerated().map { index, logged in
            SessionSet(
                order: index + 1,
                reps: logged.reps,
                weight: logged.load,
                rir: logged.rir,
                completed: true
            )
        }
        session?.addExercise(exercise, sets: sets)
        dismiss()
    }
}

// MARK: - Exercise Info

private extension AddExerciseView {
    var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXERCISE \(String(format: "%02d", (session?.exerciseCount ?? 0) + 1)) / 06")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)

            let parts = exercise.name.split(separator: " ", maxSplits: 1)
            if parts.count > 1 {
                Text(String(parts[0]))
                    .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .tracking(-1)
                Text(String(parts[1]))
                    .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .tracking(-1)
            } else {
                Text(exercise.name)
                    .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                    .tracking(-1)
            }

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

// MARK: - Preview

#Preview {
    AddExerciseView(
        exercise: Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: "QUADS",
            secondaryTags: "BILATERAL SQUAT · BILATERAL"
        )
    )
    .environment(WorkoutSession())
}
