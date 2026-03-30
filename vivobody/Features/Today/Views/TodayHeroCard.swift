import SwiftUI

struct TodayHeroCard: View {
    @Environment(WorkoutSession.self) private var session: WorkoutSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduledLabel
            workoutTitle
            workoutDetails
            exercisePills
            startButton
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.large)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, VivoSpacing.screenH)
    }

    // MARK: - Scheduled Label

    private var scheduledLabel: some View {
        Text("SCHEDULED · UPPER BODY")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.medium)
            .foregroundStyle(Color.vivoMuted)
    }

    // MARK: - Workout Title

    private var workoutTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upper Body")
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text("Push A")
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
        .padding(.top, 6)
    }

    // MARK: - Details

    private var workoutDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("06 exercises · 22 sets · ~55 min")
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoSecondary)
            Text("LAST: MAR 15 · 13,580 lb volume")
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.top, 8)
    }

    // MARK: - Exercise Pills

    private var exercisePills: some View {
        let exercises = [
            "01 BENCH PRESS", "02 INCLINE DB", "03 OHP",
            "04 CABLE FLY", "05 LAT RAISE", "06 TRI PUSHDOWN"
        ]

        return VivoFlowLayout(spacing: 6) {
            ForEach(exercises, id: \.self) { exercise in
                Text(exercise)
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                            .fill(Color.vivoSurface)
                    )
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            session?.start(name: "Upper Body Push A")
        } label: {
            Text("START WORKOUT \u{2192}")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 45)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: VivoRadius.button))
        }
        .padding(.top, 16)
    }
}

#Preview {
    TodayHeroCard()
        .background(Color.vivoBackground)
}
