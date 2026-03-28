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
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Scheduled Label

    private var scheduledLabel: some View {
        Text("SCHEDULED · UPPER BODY")
            .font(.vivoMono(12))
            .tracking(1.5)
            .foregroundStyle(Color.vivoMuted)
    }

    // MARK: - Workout Title

    private var workoutTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upper Body")
                .font(.vivoDisplay(28, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text("Push A")
                .font(.vivoDisplay(28, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
        .padding(.top, 6)
    }

    // MARK: - Details

    private var workoutDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("06 exercises · 22 sets · ~55 min")
                .font(.vivoMono(14))
                .foregroundStyle(Color.vivoSecondary)
            Text("LAST: MAR 15 · 13,580 lb volume")
                .font(.vivoMono(14))
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

        return FlowLayout(spacing: 6) {
            ForEach(exercises, id: \.self) { exercise in
                Text(exercise)
                    .font(.vivoMono(11))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
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
                .font(.vivoMono(14, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 45)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.top, 16)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + rowHeight))
    }
}

#Preview {
    TodayHeroCard()
        .background(Color.vivoBackground)
}
