//
//  MovementClassificationCard.swift
//  vivobody
//
//  The exercise detail screen's "Movement" section: how the lift
//  moves, as a diagram instead of a sentence. A cardinal-plane glyph
//  (sagittal / frontal / transverse drawn as three intersecting
//  ellipses, active planes lit) sits beside rows for pattern,
//  mechanic, and laterality. The glyph absorbs multiplane
//  combinations that read awkwardly as text ("Sagittal + Frontal +
//  Transverse"), and its presence lets the hero meta line slim down
//  to equipment alone.
//
//  Every catalog item can render this — mechanic and planes are
//  non-optional, custom exercises included. Rows with nothing to say
//  hide themselves: compound pattern is nil for isolation work, where
//  the separately authored training role takes its place; bilateral
//  laterality is the unremarkable default.
//

import SwiftUI
import VivoKit

struct MovementClassificationCard: View {
    let mechanic: Mechanic
    /// Pattern with direction folded in ("Horizontal push"). Nil for
    /// isolation work because MovementPattern is compound-specific.
    let movementLabel: String?
    let trainingRole: TrainingRole?
    let planes: [MovementPlane]
    let laterality: Laterality

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Movement")
                .sectionLabelStyle(Opacity.medium)

            HStack(alignment: .center, spacing: Space.xl) {
                MovementPlanesGlyph(activePlanes: Set(planes))
                    .frame(width: 92, height: 92)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.sm) {
                    if let movementLabel {
                        classificationRow(label: "Pattern", value: movementLabel)
                    } else if mechanic == .isolation, let trainingRole {
                        classificationRow(label: "Training", value: trainingRole.displayName)
                    }
                    classificationRow(label: "Mechanic", value: mechanic.displayName)
                    classificationRow(
                        label: "Planes",
                        value: planes.map(\.displayName).joined(separator: " · ")
                    )
                    if laterality == .unilateral {
                        classificationRow(label: "Laterality", value: laterality.displayName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.lg)
            .contentCard()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Movement")
        .accessibilityValue(accessibilitySummary)
    }

    /// One keyed row in the same vocabulary as the anatomy legend
    /// directly above: soft section label in a fixed column, value in
    /// section-heading type. Keeping the two cards rhythm-aligned
    /// makes the screen read as one anatomy-and-movement unit.
    private func classificationRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
                .minimumScaleFactor(0.7)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Spoken form of the whole card: "Horizontal push, compound,
    /// sagittal and transverse planes, unilateral."
    private var accessibilitySummary: String {
        var parts: [String] = []
        if let movementLabel {
            parts.append(movementLabel.lowercased())
        } else if mechanic == .isolation, let trainingRole {
            parts.append("\(trainingRole.displayName.lowercased()) training role")
        }
        parts.append(mechanic.displayName.lowercased())
        let planeNames = planes.map { $0.displayName.lowercased() }
        let planeList = planeNames.count > 1
            ? planeNames.dropLast().joined(separator: ", ")
            + " and " + (planeNames.last ?? "")
            : (planeNames.first ?? "")
        parts.append("\(planeList) \(planes.count > 1 ? "planes" : "plane")")
        if laterality == .unilateral {
            parts.append(laterality.displayName.lowercased())
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Plane glyph

/// The three cardinal planes as intersecting ellipses around a body
/// axis: frontal as the facing circle, sagittal as the tall edge-on
/// ellipse, transverse as the flat horizontal ellipse. Active planes
/// take the brand accent with a faint fill; inactive planes stay as
/// hairlines so the vocabulary is visible even when unselected.
/// Active strokes draw last so crossings resolve in their favor.
struct MovementPlanesGlyph: View {
    let activePlanes: Set<MovementPlane>

    /// Short-axis fraction for the edge-on ellipses. Wide enough to
    /// read as a plane rather than a line, narrow enough that the
    /// three orientations stay distinct at glyph size.
    private static let edgeOnRatio: CGFloat = 0.38

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(orderedPlanes, id: \.self) { plane in
                    planeEllipse(plane, side: side)
                }
                Circle()
                    .fill(Ink.primary.opacity(Opacity.soft))
                    .frame(width: 3, height: 3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Inactive planes first, active planes on top.
    private var orderedPlanes: [MovementPlane] {
        MovementPlane.allCases.sorted { lhs, rhs in
            activePlanes.contains(lhs) == activePlanes.contains(rhs)
                ? false
                : !activePlanes.contains(lhs)
        }
    }

    private func planeEllipse(_ plane: MovementPlane, side: CGFloat) -> some View {
        let isActive = activePlanes.contains(plane)
        let stroke: Color = isActive ? Tint.primary : Ink.primary.opacity(Opacity.faint)
        return Ellipse()
            .fill(isActive ? Tint.primary.opacity(0.08) : .clear)
            .overlay(
                Ellipse().stroke(stroke, lineWidth: isActive ? 1.5 : 1)
            )
            .frame(
                width: plane == .sagittal ? side * Self.edgeOnRatio : side,
                height: plane == .transverse ? side * Self.edgeOnRatio : side
            )
    }
}

// MARK: - Detail screen section

extension ExerciseDetailScreen {
    /// How the lift moves, directly under the anatomy figure so the
    /// screen reads what it works, then how it moves, then how to do
    /// it. The builder lives beside the card for the same reason
    /// `instructionsLink` lives in ExerciseInstructionsScreen.swift —
    /// and to keep the oversized sections file under its ratchet.
    var movementSection: some View {
        MovementClassificationCard(
            mechanic: item.mechanic,
            movementLabel: item.movementLabel,
            trainingRole: item.trainingRole,
            planes: item.planes,
            laterality: item.laterality
        )
    }
}

#if DEBUG
    #Preview("Movement classification") {
        ScrollView {
            VStack(spacing: Space.xxl) {
                MovementClassificationCard(
                    mechanic: .compound,
                    movementLabel: "Horizontal push",
                    trainingRole: .push,
                    planes: [.sagittal],
                    laterality: .bilateral
                )
                MovementClassificationCard(
                    mechanic: .compound,
                    movementLabel: "Diagonal pull",
                    trainingRole: .pull,
                    planes: [.sagittal, .transverse],
                    laterality: .unilateral
                )
                MovementClassificationCard(
                    mechanic: .compound,
                    movementLabel: "Loaded carry",
                    trainingRole: .other,
                    planes: [.sagittal, .frontal, .transverse],
                    laterality: .bilateral
                )
                MovementClassificationCard(
                    mechanic: .isolation,
                    movementLabel: nil,
                    trainingRole: .push,
                    planes: [.frontal],
                    laterality: .bilateral
                )
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
