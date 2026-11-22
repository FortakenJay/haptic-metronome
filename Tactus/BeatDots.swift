import SwiftUI

/// One dot per beat of the bar, with a wider gap between groups, so 7/8 as 2+2+3 reads as ●○ ○○ ○○○.
/// While playing, the beat that just tapped is lit. Beat 1 is a little larger than the rest.
///
/// Decorative for VoiceOver: the dial's accessibility value already says the meter and grouping.
struct BeatDots: View {
    let meter: Meter
    let current: Int
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 7) {   // gap between groups
            ForEach(Array(groupRanges.enumerated()), id: \.offset) { _, range in
                HStack(spacing: 3) {   // gap within a group
                    ForEach(range, id: \.self) { beat in
                        Circle()
                            .fill(color(for: beat))
                            .frame(width: size(for: beat), height: size(for: beat))
                    }
                }
            }
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }

    /// Beat indices of each group: 3+2 → [0..<3, 3..<5].
    private var groupRanges: [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        for size in meter.groups {
            ranges.append(start..<(start + size))
            start += size
        }
        return ranges
    }

    private func size(for beat: Int) -> CGFloat {
        beat == 0 ? 9 : (meter.groupStarts.contains(beat) ? 7 : 6)
    }

    private func color(for beat: Int) -> Color {
        if isPlaying && beat == current { return .accentColor }
        return Color.gray.opacity(meter.groupStarts.contains(beat) ? 0.7 : 0.4)
    }
}

#Preview {
    VStack(spacing: 12) {
        BeatDots(meter: Meter(7, 8, groups: [2, 2, 3]), current: 4, isPlaying: true)
        BeatDots(meter: Meter(5, 4, groups: [3, 2]), current: 0, isPlaying: false)
        BeatDots(meter: Meter(12, 8, groups: [3, 3, 3, 3]), current: 7, isPlaying: true)
    }
}
