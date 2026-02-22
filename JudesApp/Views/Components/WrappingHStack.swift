import SwiftUI

struct WrappingHStack: View {
    let words: [TimedWord]
    let currentIndex: Int?

    var body: some View {
        WrappingLayout(horizontalSpacing: 6, verticalSpacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, timedWord in
                Text(timedWord.word)
                    .font(.system(size: 32, weight: isCurrentWord(index) ? .bold : .medium))
                    .foregroundStyle(isCurrentWord(index) ? .yellow : .white.opacity(0.7))
                    .scaleEffect(isCurrentWord(index) ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: currentIndex)
                    .id(index)
            }
        }
    }

    private func isCurrentWord(_ index: Int) -> Bool {
        currentIndex == index
    }
}

// MARK: - Custom Wrapping Layout

struct WrappingLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if index < rows.count - 1 {
                height += verticalSpacing
            }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX

            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += rowHeight + verticalSpacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentRowWidth += size.width + horizontalSpacing
        }

        return rows
    }
}
