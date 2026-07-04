//
//  HapticsGallery.swift
//  vivobody
//
//  Interactive preview for the haptics engine.
//  Tap any row to feel it. Haptics fire on device only —
//  the visual pulse confirms the tap registered in the canvas.
//

import VivoKit
import SwiftUI

struct HapticsGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header

                section(title: "ATOMS") {
                    HapticRow(label: "tick",      subtitle: "scrubber increments")    { Haptics.tick() }
                    HapticRow(label: "thunk",     subtitle: "set complete")           { Haptics.thunk() }
                    HapticRow(label: "slam",      subtitle: "PR, final set")          { Haptics.slam() }
                    HapticRow(label: "rigid",     subtitle: "hard stops")             { Haptics.rigid() }
                    HapticRow(label: "soft",      subtitle: "subtle transitions")     { Haptics.soft() }
                    HapticRow(label: "selection", subtitle: "picker, segments")       { Haptics.selection() }
                }

                section(title: "NOTIFICATIONS") {
                    HapticRow(label: "success", subtitle: "PR confirmed")              { Haptics.success() }
                    HapticRow(label: "warning", subtitle: "rest ending soon")          { Haptics.warning() }
                    HapticRow(label: "failure", subtitle: "missed rep — sparingly")    { Haptics.failure() }
                }

                section(title: "PATTERNS") {
                    HapticRow(label: "crescendo", subtitle: "set complete (signature)") { Haptics.crescendo() }
                    HapticRow(label: "breath",    subtitle: "rest timer warning")       { Haptics.breath() }
                    HapticRow(label: "swell",     subtitle: "PR celebration")           { Haptics.swell() }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, Space.xxl)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HAPTICS")
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Tap to feel.")
                .font(Typography.display)
                .foregroundStyle(.white)
            Text("Haptics fire on a real device. Simulator and preview canvas show only the visual pulse.")
                .font(Typography.sectionLabel)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            VStack(spacing: 8) { content() }
        }
    }
}

// MARK: - Row

private struct HapticRow: View {
    let label: String
    let subtitle: String
    let action: () -> Void

    @State private var pulseId = 0

    var body: some View {
        Button {
            action()
            pulseId &+= 1
        } label: {
            HStack(spacing: Space.lg) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(Typography.statValue)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                PulseDot(triggerId: pulseId)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }
}

private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - Pulse dot (visual confirmation in preview canvas)

private struct PulseDot: View {
    let triggerId: Int

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.18

    var body: some View {
        Circle()
            .fill(Color.white)
            .opacity(opacity)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .onChange(of: triggerId) { _, _ in
                scale = 1
                opacity = 1
                withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
                    scale = 1.8
                }
                withAnimation(.easeOut(duration: 0.45)) {
                    opacity = 0.18
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.45)) {
                    scale = 1
                }
            }
    }
}

#Preview("Haptics Gallery") {
    HapticsGallery()
        .preferredColorScheme(.dark)
}
