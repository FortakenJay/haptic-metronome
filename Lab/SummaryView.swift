import SwiftUI

/// The report after a take: one sentence on top, then the numbers behind it.
struct SummaryView: View {
    let summary: TakeSummary
    let note: String?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                Divider()
                if let median = summary.median {
                    row("Overall", TakeSummary.describe(median))
                }
                if let spread = summary.spread {
                    row("Steadiness", "± \(TakeSummary.ms(spread))")
                }
                if let dense = summary.dense {
                    row("In runs", TakeSummary.describe(dense))
                }
                if let sparse = summary.sparse {
                    row("Elsewhere", TakeSummary.describe(sparse))
                }
                if let stretch = summary.worstStretch {
                    row("Furthest off", "bars \(stretch.firstBar)–\(stretch.lastBar), \(TakeSummary.describe(stretch.median))")
                }
                row("Notes", "\(summary.noteCount) on the grid, \(summary.unmatched) off it")
                Button("Done", action: onDone)
                    .padding(.top, 6)
            }
        }
        .navigationTitle("Take")
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.body).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
