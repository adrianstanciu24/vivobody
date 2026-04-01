import SwiftUI

struct WorkoutsHistoryEmptyStateView: View {
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @State private var showStartPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                emptyCard
                VivoFooter(
                    line1: "VIVOBODY WORKOUT SYS",
                    line2: "SESSIONS: 0 LOGGED",
                    line3: "TRAIN HARD · LOG EVERYTHING"
                )
            }
            .padding(.bottom, 32)
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoAccent, lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.vivoAccent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("NO WORKOUTS YET")
                        .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(Color.vivoAccent)
                    Text(
                        "Complete your first session to start tracking your progress."
                    )
                    .font(.vivoMono(VivoFont.monoDefault))
                    .lineSpacing(2)
                    .foregroundStyle(Color.vivoMuted)
                }
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.bottom, 16)

            instructionRow(
                number: "01",
                title: "START A SESSION",
                detail: "Tap the button below or go to the Today tab to begin."
            )
            .padding(.bottom, 14)

            instructionRow(
                number: "02",
                title: "TRACK YOUR PROGRESS",
                detail: "Every completed workout appears here with full stats and history."
            )
            .padding(.bottom, 16)

            Button {
                showStartPicker = true
            } label: {
                Text("START WORKOUT \u{2192}")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.vivoAccent)
                    .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                    .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
            }
            .sheet(isPresented: $showStartPicker) {
                StartWorkoutPicker()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .padding(VivoSpacing.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoAccent, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 14)
    }

    private func instructionRow(
        number: String, title: String, detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoMuted)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoPrimary)
                Text(detail)
                    .font(.vivoMono(VivoFont.monoSM))
                    .lineSpacing(2)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
    }
}

#Preview {
    WorkoutsHistoryEmptyStateView()
        .background(Color.vivoBackground)
        .environment(WorkoutSession())
}
