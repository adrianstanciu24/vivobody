import SwiftUI

struct SlideToFinishBar: View {
    let onFinish: () -> Void

    @State private var offset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    @State private var completed = false

    private let thumbSize: CGFloat = 56
    private let trackHeight: CGFloat = 56
    private let threshold: CGFloat = 0.8

    private var maxOffset: CGFloat {
        max(0, trackWidth - thumbSize)
    }

    private var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(offset / maxOffset, 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            track
            label
            thumb
        }
        .frame(height: trackHeight)
        .padding(.horizontal, VivoSpacing.screenH)
        .allowsHitTesting(!completed)
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.card)
                            .stroke(Color.vivoAccent.opacity(0.4), lineWidth: 1.5)
                    )

                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .fill(Color.vivoAccent)
                    .frame(width: offset + thumbSize)
            }
            .onAppear { trackWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, width in trackWidth = width }
        }
    }

    private var labelText: String {
        if progress > 0.15 { return "WORKOUT COMPLETE \u{2713}" }
        return "SLIDE TO FINISH \u{2192}"
    }

    private var label: some View {
        Text(labelText)
            .font(.vivoMono(VivoFont.monoSM, weight: .bold))
            .tracking(VivoTracking.medium)
            .foregroundStyle(progress > 0.15 ? Color.white : Color.vivoAccent)
            .frame(maxWidth: .infinity)
    }

    private var thumb: some View {
        RoundedRectangle(cornerRadius: VivoRadius.card)
            .fill(Color.vivoAccent)
            .frame(width: thumbSize, height: trackHeight)
            .overlay(
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = min(max(0, value.translation.width), maxOffset)
                    }
                    .onEnded { _ in
                        if progress >= threshold {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = maxOffset
                                completed = true
                            }
                            onFinish()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
    }
}

#Preview {
    SlideToFinishBar {}
        .background(Color.vivoBackground)
}
