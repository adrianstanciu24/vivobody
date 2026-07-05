//
//  PaywallSheet.swift
//  vivobody
//
//  The one purchase surface. Presented as a sheet from AppRoot,
//  bound to `ProStore.isPaywallPresented` so every gate in the app
//  (Insights, template limit, charts, Settings, widget deep link)
//  lands on the same screen. Black, type-forward, single accent —
//  no checkmark spam, no countdown timers, no dark patterns.
//
//  Price always comes from `Product.displayPrice`; nothing is
//  hardcoded. Restore Purchases is always reachable (App Review
//  requirement). A successful purchase dismisses with the same
//  rigid haptic thunk a completed set earns.
//

import VivoKit
import SwiftUI

struct PaywallSheet: View {
    let pro: ProStore

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header
                featureList
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.section)
            .padding(.bottom, Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .forgeBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: pro.status) { _, status in
            if status == .pro {
                Haptics.rigid()
                dismiss()
            }
        }
        .alert(
            "Purchase didn't go through",
            isPresented: errorBinding
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(pro.purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("vivobody")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                Text("PRO")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Tint.primary))
            }
            Text("Logging is free forever. Pro unlocks the depth layer — what all that training means.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 0) {
            featureRow(
                title: "Insights",
                detail: "Signature, strength trajectory, symmetry, training load — the full read on your training"
            )
            SectionDivider()
            featureRow(
                title: "Progress charts",
                detail: "Per-exercise weight, e1RM, and volume trends with PR markers"
            )
            SectionDivider()
            featureRow(
                title: "Unlimited templates",
                detail: "The free tier includes \(ProGate.freeTemplateLimit)"
            )
            SectionDivider()
            featureRow(
                title: "Home Screen widgets",
                detail: "Your Signature and Consistency, at a glance"
            )
            SectionDivider()
            featureRow(
                title: "Apple Health",
                detail: "Finished workouts mirrored to the Health app"
            )
        }
    }

    private func featureRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Purchase bar

    private var purchaseBar: some View {
        VStack(spacing: Space.md) {
            Button {
                guard !isPurchasing else { return }
                Haptics.soft()
                isPurchasing = true
                Task {
                    await pro.purchase()
                    isPurchasing = false
                }
            } label: {
                HStack(spacing: 0) {
                    Text("Unlock Forever")
                    Spacer(minLength: Space.sm)
                    if isPurchasing {
                        ProgressView()
                            .tint(Tint.onAccent)
                    } else if let price = pro.displayPrice {
                        Text(price)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPurchasing)
            .accessibilityLabel("Unlock Vivobody Pro forever")

            Button {
                guard !isRestoring else { return }
                isRestoring = true
                Task {
                    await pro.restore()
                    isRestoring = false
                }
            } label: {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.secondary)
                    .frame(minHeight: Space.tapMin)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)

            Text("One-time purchase. No subscription. Your data never leaves your device.")
                .font(Typography.micro)
                .foregroundStyle(Ink.quaternary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
    }

    // MARK: - Plumbing

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { pro.purchaseError != nil },
            set: { if !$0 { pro.purchaseError = nil } }
        )
    }
}

#Preview("Paywall") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            PaywallSheet(pro: ProStore())
        }
        .preferredColorScheme(.dark)
}
