//
//  HealthKitPrimingSheet.swift
//  vivobody
//
//  One-screen explainer shown before the first Apple Health
//  authorization prompt. HealthKit is opt-in behind a Settings
//  toggle; the first time the user flips it on, this sheet
//  explains what is shared (finished workouts only) before the
//  system permission sheet appears. "Continue" triggers the real
//  request; "Not Now" leaves the toggle off. The sheet is pure UI —
//  the authorization side effect lives in the owning screen via the
//  onContinue / onNotNow closures.
//

import SwiftUI

struct HealthKitPrimingSheet: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.lg) {
                            iconBadge
                            Text("Send your finished workouts to the Health app so they appear in your workout history alongside your other activity.")
                                .font(Typography.body)
                                .foregroundStyle(Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            bulletList
                        }
                        .padding(.top, Space.lg)
                        .padding(.bottom, Space.lg)
                    }
                    .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)

                    PrimaryActionButton(
                        title: "Continue",
                        subtitle: "Allow sharing workouts"
                    ) {
                        onContinue()
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xxl)
                }
            }
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not Now") { onNotNow() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var iconBadge: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Tint.primary)
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(Tint.primary.opacity(0.12))
            )
            .accessibilityHidden(true)
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            bullet("checkmark.circle", "Workouts only. No calories or other health data.")
            bullet("checkmark.circle", "Vivobody keeps your history. Health is a mirror.")
            bullet("checkmark.circle", "Turn it off anytime in Settings.")
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: icon)
                .font(Typography.body)
                .foregroundStyle(Tint.primary)
                .frame(width: 24)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HealthKitPrimingSheet(onContinue: {}, onNotNow: {})
        .preferredColorScheme(.dark)
}
