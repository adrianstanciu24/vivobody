import SwiftUI

struct WorkoutTemplatesEmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                emptyCard
                VivoFooter(
                    line1: "VIVOBODY WORKOUT SYS",
                    line2: "TEMPLATES: 0 CREATED",
                    line3: "BUILD ONCE · REUSE FOREVER"
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
                        Text("+")
                            .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                            .foregroundStyle(Color.vivoAccent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("NO TEMPLATES YET")
                        .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(Color.vivoAccent)
                    Text(
                        "Create a reusable workout template to speed up your sessions."
                    )
                    .font(.vivoMono(VivoFont.monoCaption))
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
                title: "BUILD YOUR TEMPLATE",
                detail: "Pick exercises, set target reps and sets for each move."
            )
            .padding(.bottom, 14)

            instructionRow(
                number: "02",
                title: "USE IT ANYTIME",
                detail: "Start a session from any template — adjust on the fly as needed."
            )
            .padding(.bottom, 16)

            Button(action: onCreate) {
                Text("+ CREATE TEMPLATE")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.vivoAccent)
                    .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                    .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
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
                    .font(.vivoMono(VivoFont.monoCaption))
                    .lineSpacing(2)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
    }
}

#Preview {
    WorkoutTemplatesEmptyStateView {}
        .background(Color.vivoBackground)
}
