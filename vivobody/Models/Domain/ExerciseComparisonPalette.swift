//
//  ExerciseComparisonPalette.swift
//  vivobody
//
//  Contrast-safe UI colors for Exercise Comparison identity labels and
//  selected controls. These are deliberately separate from MuscleColor's
//  mesh-oriented anatomy ramps: a color that reads well across a shaded 3D
//  surface is not automatically accessible as small text on a flat card.
//

nonisolated enum ExerciseComparisonPalette {
    /// A/B label color on the screen background and content cards. Dark-mode
    /// colors are bright; light-mode colors deepen enough to clear WCAG AA.
    static func labelRGB(
        for tint: MuscleMapTint,
        theme: BodyModelTheme
    ) -> MuscleColor.RGB {
        switch (tint, theme) {
        case (.accent, .dark):
            MuscleColor.RGB(red: 1.00, green: 0.48, blue: 0.10)
        case (.accent, .light):
            MuscleColor.RGB(red: 0.58, green: 0.20, blue: 0.00)
        case (.compare, .dark):
            MuscleColor.RGB(red: 0.38, green: 0.62, blue: 1.00)
        case (.compare, .light):
            MuscleColor.RGB(red: 0.08, green: 0.25, blue: 0.64)
        }
    }

    /// Selected controls use the bright variants in both appearances with
    /// black foreground content. Each pairing exceeds 7:1 before the system
    /// glass treatment, leaving margin for material blending.
    static func controlFillRGB(for tint: MuscleMapTint) -> MuscleColor.RGB {
        switch tint {
        case .accent:
            MuscleColor.RGB(red: 1.00, green: 0.48, blue: 0.10)
        case .compare:
            MuscleColor.RGB(red: 0.38, green: 0.62, blue: 1.00)
        }
    }

    static let controlForegroundRGB = MuscleColor.RGB(red: 0, green: 0, blue: 0)
}
