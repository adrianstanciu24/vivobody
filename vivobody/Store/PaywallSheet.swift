//
//  PaywallSheet.swift
//  vivobody
//
//  The one purchase surface. Every gate in the app (Insights, Exercise
//  Detail, comparison, the template limit, Settings, and the locked
//  widgets) lands here. Type-forward, single accent, no countdowns or
//  dark patterns. The price always comes from the App Store, and
//  Restore Purchases is always reachable.
//

import SwiftUI
import VivoKit

struct PaywallSheet: View {
    let pro: ProStore

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header
                if let notice = contextNotice {
                    contextBanner(notice)
                }
                featureList
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.section)
            .padding(.bottom, Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .screenBackground()
        .task { await pro.loadProductIfNeeded() }
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
            Button("OK", role: .cancel) {}
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
            Text("Logging is free forever. Pro unlocks what all that training means.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Context notice

    private var contextNotice: String? {
        switch pro.paywallContext {
        case .general:
            nil
        case .templateLimit:
            "You've reached the free limit of \(ProGate.freeTemplateLimit) templates. Pro removes the cap."
        }
    }

    private func contextBanner(_ text: String) -> some View {
        Text(text)
            .font(Typography.sectionHeading)
            .foregroundStyle(Tint.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentCard(tint: Tint.primary)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 0) {
            featureRow(
                title: "Insights",
                detail: "Training signature, load, rhythm, stamina, and balance from your own history"
            )
            rowDivider
            featureRow(
                title: "Exercise instruments",
                detail: "Progress chart, last 7 days, load cadence, and set-series stamina for every exercise"
            )
            rowDivider
            featureRow(
                title: "Exercise comparison",
                detail: "Two exercises side by side: muscles, movement, and record eligibility"
            )
            rowDivider
            featureRow(
                title: "Unlimited templates",
                detail: "The free version includes up to \(ProGate.freeTemplateLimit)"
            )
            rowDivider
            featureRow(
                title: "Home Screen widgets",
                detail: "Training Signature, Consistency, and Training Load at a glance"
            )
        }
        .contentCard()
    }

    private func featureRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
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
            .primaryButtonStyle()
            .disabled(isPurchasing)
            .accessibilityLabel(pro.displayPrice.map { "Unlock Vivobody Pro forever, \($0)" } ?? "Unlock Vivobody Pro forever")
            .accessibilityIdentifier("paywallPurchaseButton")

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
                .foregroundStyle(Ink.tertiary)
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
