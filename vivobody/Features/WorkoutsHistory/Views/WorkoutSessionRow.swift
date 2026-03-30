import SwiftData
import SwiftUI

struct WorkoutSessionRow: View {
    let workout: Workout
    var highlight = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                WorkoutSessionDateColumn(workout: workout)
                    .frame(width: 72)
                    .padding(.trailing, 12)

                WorkoutSessionDetails(workout: workout)

                Spacer()

                WorkoutSessionTrailing(workout: workout)
            }
            .padding(.vertical, 14)
            .frame(minHeight: 96)
            .background(highlight ? Color.vivoAccent.opacity(0.04) : .clear)
            .overlay(alignment: .leading) {
                if highlight {
                    Rectangle()
                        .fill(Color.vivoAccent)
                        .frame(width: 3)
                        .padding(.leading, 20)
                }
            }

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.horizontal, VivoSpacing.screenH)
        }
    }
}

// MARK: - Date Column

struct WorkoutSessionDateColumn: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.dayOfWeekIndex)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Text(workout.dayOfWeek)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoSecondary)

            Text(workout.dayNumber)
                .font(.vivoMono(VivoFont.sectionTitle, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
        .padding(.leading, VivoSpacing.screenH)
    }
}

// MARK: - Session Details

struct WorkoutSessionDetails: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.notes.isEmpty ? "Custom Workout" : workout.notes)
                .font(.vivoDisplay(VivoFont.sectionTitle, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text(workout.exerciseSummary)
                .font(.vivoMono(VivoFont.monoMD))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)

            WorkoutSessionStatsLine(workout: workout)
        }
    }
}

// MARK: - Stats Line

struct WorkoutSessionStatsLine: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 0) {
            Text(workout.durationFormatted)
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" \u{00B7} ")
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoMuted)
            Text(workout.volumeFormatted)
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" \u{00B7} ")
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoMuted)
            Text(workout.setsFormatted)
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
    }
}

// MARK: - Trailing (Checkmark + Time)

#Preview {
    WorkoutSessionRow(workout: Workout(startedAt: .now))
        .background(Color.vivoBackground)
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}

struct WorkoutSessionTrailing: View {
    let workout: Workout

    var body: some View {
        VStack(spacing: 4) {
            Text("\u{2713}")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoGreen)
            Text(workout.relativeTimeAgo)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.trailing, VivoSpacing.screenH)
    }
}
