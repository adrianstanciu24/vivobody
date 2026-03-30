import SwiftUI

struct ExerciseDetailFormNotesView: View {
    private static let notes: [FormNote] = [
        FormNote(
            text: "Focus on controlled eccentric — 3 sec down. Keep shoulder blades pinched throughout.",
            session: "PUSH DAY · MAR 15"
        ),
        FormNote(
            text: "Slight arch, feet flat. Touch below nipple line. Drive through heels on press.",
            session: "PUSH DAY · MAR 05"
        ),
        FormNote(
            text: "Wrist wraps helped at 205+. Keep elbows at ~45° not flared.",
            session: "UPPER BODY · FEB 28"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            ForEach(Array(Self.notes.enumerated()), id: \.offset) { _, note in
                FormNoteRow(note: note)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("FORM NOTES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("+ ADD")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoAccent)
        }
        .padding(.bottom, VivoSpacing.itemGap)
    }
}

// MARK: - Data

struct FormNote {
    let text: String
    let session: String
}

// MARK: - Note Row

struct FormNoteRow: View {
    let note: FormNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.text)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(note.session)
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.vertical, VivoSpacing.tightGap)
    }
}

#Preview {
    ExerciseDetailFormNotesView()
        .background(Color.vivoBackground)
}
