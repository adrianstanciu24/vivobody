//
//  PlateVisualizer.swift
//  vivobody
//
//  Side-on view of an Olympic barbell with plates loaded symmetrically.
//
//  Plate sizing and color follow real-world conventions (IPF colors where
//  they apply): a 45 lb plate visibly dwarfs a 2.5 lb plate, and adding
//  a 25 looks unmistakably like *adding a 25*. Plate transitions slide in
//  and out from the outer edges with spring physics — adding 10 lb feels
//  like "two 5s appearing on the bar," not a number ticking.
//
//  Use:
//      PlateVisualizer(weight: 135)
//      PlateVisualizer(weight: 100, unit: .kg)
//

import SwiftUI

// `WeightUnit` (lb / kg) lives in Models/WeightUnit.swift now so
// every layer (formatter, scrubber, display) shares one source of
// truth. PlateVisualizer just consumes the enum's `standardBarWeight`
// and `standardPlates` accessors here.

struct LoadedPlate: Identifiable, Hashable {
    let weight: Double
    let copy: Int
    var id: String { "\(weight)-\(copy)" }
}

enum PlateMath {
    /// Greedy: largest plates first. Returns the plates loaded per side
    /// (nearest the collar first), plus the weight actually achieved.
    static func load(perSide: Double, available: [Double]) -> (plates: [LoadedPlate], achieved: Double) {
        var remaining = perSide
        var result: [LoadedPlate] = []
        var copyCount: [Double: Int] = [:]
        for plate in available.sorted(by: >) {
            while remaining >= plate - 0.0001 {
                let copy = copyCount[plate, default: 0]
                result.append(LoadedPlate(weight: plate, copy: copy))
                copyCount[plate] = copy + 1
                remaining -= plate
            }
        }
        return (result, perSide - remaining)
    }
}

struct PlateVisualizer: View {
    let weight: Double
    var barWeight: Double = 45
    var unit: WeightUnit = .lb
    var availablePlates: [Double]? = nil

    private var plates: [Double] { availablePlates ?? unit.standardPlates }
    private var perSide: Double { max(0, (weight - barWeight) / 2) }

    private var math: (plates: [LoadedPlate], achieved: Double) {
        PlateMath.load(perSide: perSide, available: plates)
    }

    private var actualTotal: Double { barWeight + 2 * math.achieved }
    private var isExact: Bool { abs(actualTotal - weight) < 0.01 }

    var body: some View {
        let m = math
        let intrinsicWidth = intrinsicBarWidth(for: m.plates)
        return VStack(spacing: Space.lg) {
            GeometryReader { geo in
                let availableWidth = geo.size.width
                let scale = intrinsicWidth > availableWidth && availableWidth > 0
                    ? availableWidth / intrinsicWidth
                    : 1.0

                HStack(alignment: .center, spacing: 0) {
                    BarSegment(width: Self.lipWidth, gradient: barGradient)
                    ForEach(m.plates.reversed()) { plate in
                        PlateView(plate: plate, unit: unit)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    BarCollarBump()
                    BarSegment(width: Self.shaftWidth, gradient: barGradient)
                    BarCollarBump()
                    ForEach(m.plates) { plate in
                        PlateView(plate: plate, unit: unit)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    BarSegment(width: Self.lipWidth, gradient: barGradient)
                }
                .frame(height: 130)
                .scaleEffect(scale, anchor: .center)
                .frame(width: availableWidth, height: 130, alignment: .center)
                .animation(.spring(response: 0.42, dampingFraction: 0.72), value: m.plates)
            }
            .frame(height: 130)

            label(actual: actualTotal, exact: isExact)
        }
    }

    /// Analytical width of the loaded barbell at scale 1.0. Used to drive
    /// the scale-to-fit transform when the bar would otherwise overflow
    /// its container at heavy loads.
    private func intrinsicBarWidth(for plates: [LoadedPlate]) -> CGFloat {
        let collarBumpWidth: CGFloat = 5
        let plateWidthsPerSide = plates.reduce(0.0) { sum, plate in
            sum + PlateAppearance.for(weight: plate.weight, unit: unit).width
        }
        return 2 * Self.lipWidth
            + 2 * collarBumpWidth
            + Self.shaftWidth
            + 2 * plateWidthsPerSide
    }

    // Bar geometry constants
    private static let lipWidth: CGFloat = 18
    private static let shaftWidth: CGFloat = 80
    static let barThickness: CGFloat = 11

    private func label(actual: Double, exact: Bool) -> some View {
        HStack(spacing: 4) {
            if !exact {
                Text("≈")
                    .foregroundStyle(Ink.secondary)
            }
            DigitTicker(
                value: actual,
                font: Typography.metricUnit,
                color: Ink.secondary,
                fractionalDigits: actual.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
            )
            Text(unit.rawValue)
                .foregroundStyle(Ink.tertiary)
                .padding(.leading, 2)
        }
        .font(Typography.metricUnit)
        .foregroundStyle(Ink.secondary)
        .tracking(1.5)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.42, blue: 0.46),
                Color(red: 0.82, green: 0.82, blue: 0.85),
                Color(red: 0.42, green: 0.42, blue: 0.46),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Plate view

private struct PlateView: View {
    let plate: LoadedPlate
    let unit: WeightUnit

    private static let corner: CGFloat = 2.5

    var body: some View {
        let app = PlateAppearance.for(weight: plate.weight, unit: unit)
        let stripeHeight = max(6, app.height * 0.32)

        return ZStack {
            // Body — dark rubber with vertical gradient for cylindrical depth.
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.17, blue: 0.19),
                    Color(red: 0.10, green: 0.10, blue: 0.12),
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Colored identification stripe (the only color on the plate).
            Rectangle()
                .fill(app.color)
                .frame(height: stripeHeight)
                .overlay(
                    // Subtle inner shading on the stripe so it has its own form.
                    LinearGradient(
                        colors: [Color.black.opacity(0.18), Color.clear, Color.black.opacity(0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: stripeHeight)
                )

            // Top edge highlight — the rim of the plate catching light.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(8, app.height * 0.20))
                Spacer(minLength: 0)
            }
        }
        .frame(width: app.width, height: app.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .stroke(Color.black.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 2.5, x: 0, y: 1.5)
    }
}

// MARK: - Bar pieces

/// One continuous-looking segment of the bar. Drawn between plates so the
/// bar appears to pass behind them while the total length scales with load.
private struct BarSegment: View {
    let width: CGFloat
    let gradient: LinearGradient

    var body: some View {
        Capsule()
            .fill(gradient)
            .frame(width: width, height: PlateVisualizer.barThickness)
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
    }
}

/// The raised ring at the shaft / sleeve junction. Sells "plates are seated."
private struct BarCollarBump: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.45, blue: 0.48),
                        Color(red: 0.95, green: 0.95, blue: 0.97),
                        Color(red: 0.45, green: 0.45, blue: 0.48),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 5, height: PlateVisualizer.barThickness + 6)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
    }
}

// MARK: - Plate appearance (color + dimensions per weight)

private struct PlateAppearance {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    static func `for`(weight: Double, unit: WeightUnit) -> PlateAppearance {
        switch unit {
        case .lb: return appearanceLB(weight: weight)
        case .kg: return appearanceKG(weight: weight)
        }
    }

    private static func appearanceLB(weight: Double) -> PlateAppearance {
        switch weight {
        case 45:   return .init(color: Color(red: 0.78, green: 0.20, blue: 0.20), width: 17, height: 118)
        case 35:   return .init(color: Color(red: 0.28, green: 0.42, blue: 0.68), width: 15, height: 102)
        case 25:   return .init(color: Color(red: 0.22, green: 0.55, blue: 0.32), width: 13, height: 85)
        case 10:   return .init(color: Color(red: 0.72, green: 0.72, blue: 0.70), width: 10, height: 62)
        case 5:    return .init(color: Color(red: 0.40, green: 0.62, blue: 0.78), width: 8,  height: 48)
        case 2.5:  return .init(color: Color(red: 0.82, green: 0.32, blue: 0.30), width: 7,  height: 36)
        case 1.25: return .init(color: Color(red: 0.62, green: 0.62, blue: 0.66), width: 6,  height: 28)
        default:   return .init(color: Color.gray,                                   width: 8,  height: 44)
        }
    }

    private static func appearanceKG(weight: Double) -> PlateAppearance {
        switch weight {
        case 25:   return .init(color: Color(red: 0.78, green: 0.20, blue: 0.20), width: 17, height: 118)
        case 20:   return .init(color: Color(red: 0.28, green: 0.42, blue: 0.68), width: 16, height: 112)
        case 15:   return .init(color: Color(red: 0.88, green: 0.72, blue: 0.22), width: 15, height: 102)
        case 10:   return .init(color: Color(red: 0.22, green: 0.55, blue: 0.32), width: 13, height: 85)
        case 5:    return .init(color: Color(red: 0.72, green: 0.72, blue: 0.70), width: 10, height: 62)
        case 2.5:  return .init(color: Color(red: 0.82, green: 0.32, blue: 0.30), width: 7,  height: 36)
        case 1.25: return .init(color: Color(red: 0.62, green: 0.62, blue: 0.66), width: 6,  height: 28)
        case 0.5:  return .init(color: Color(red: 0.50, green: 0.68, blue: 0.85), width: 5,  height: 22)
        default:   return .init(color: Color.gray,                                   width: 8,  height: 44)
        }
    }
}
