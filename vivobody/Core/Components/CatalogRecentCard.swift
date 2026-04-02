import SwiftUI

struct CatalogRecentCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.body))
                .foregroundStyle(Color.vivoPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(exercise.tags)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)

            Spacer()

            Text(exercise.motionFamily.replacing("_", with: " ").uppercased())
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoAccent)
        }
        .padding(14)
        .frame(width: 180, height: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

#Preview {
    CatalogRecentCard(
        exercise: Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: "QUADS",
            secondaryTags: "BILATERAL SQUAT · BILATERAL",
            motionFamily: "bilateral_squat"
        )
    )
    .background(Color.vivoBackground)
}
