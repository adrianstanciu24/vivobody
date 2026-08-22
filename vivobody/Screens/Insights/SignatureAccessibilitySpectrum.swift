//
//  SignatureAccessibilitySpectrum.swift
//  vivobody
//
//  Large-type counterpart to the Insights training-shape bloom. It preserves
//  the same six-way visual signal with rails whose labels can wrap naturally.
//

import SwiftUI
import VivoKit

func signatureShareLabel(_ share: Double) -> String {
    guard share > 0 else { return "0%" }
    let percentage = share * 100
    return percentage < 1 ? "<1%" : "\(Int(percentage.rounded()))%"
}

func signatureShareSpokenLabel(_ share: Double) -> String {
    guard share > 0 else { return "0 percent" }
    let percentage = share * 100
    return percentage < 1
        ? "less than 1 percent"
        : "\(Int(percentage.rounded())) percent"
}

struct SignatureAccessibilitySpectrum: View {
    let signature: TrainingSignature

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ForEach(signature.petals) { petal in
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        Text(petal.group.displayName)
                            .font(Typography.sectionHeading)
                            .foregroundStyle(
                                petal.group == signature.dominantGroup
                                    ? Tint.primaryText
                                    : Ink.primary
                            )
                        Spacer(minLength: Space.sm)
                        Text(signatureShareLabel(petal.volumeShare))
                            .font(Typography.metricInline)
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                    }

                    GeometryReader { proxy in
                        let scaleMaximum = 0.5
                        let fill = max(0, min(1, petal.volumeShare / scaleMaximum))
                        let marker = SignatureEmblemTuning.equalShare / scaleMaximum
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Surface.cardTint)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Tint.primary, Tint.primary.opacity(0.36)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: petal.volumeShare > 0
                                        ? max(3, proxy.size.width * CGFloat(fill))
                                        : 0
                                )
                                .shadow(color: Tint.primary.opacity(0.34), radius: 6)
                            Path { path in
                                let x = proxy.size.width * CGFloat(marker)
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: 12))
                            }
                            .stroke(
                                Ink.primary.opacity(0.42),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                            )
                        }
                    }
                    .frame(height: 12)
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(petal.group.displayName), \(signatureShareSpokenLabel(petal.volumeShare)) of all completed strength work"
                )
            }

            Text("The dashed marker is an even six-way share.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .padding(Space.xl)
        .contentCard()
    }
}
