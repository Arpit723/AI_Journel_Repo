import SwiftUI

// MARK: - Flow layout

/// Wraps its subviews left-to-right, moving to a new line when the current
/// row runs out of horizontal space. Built for the tag pill row (spec §1.1,
/// §2.1–2.2) but works for any row of variable-width chips.
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Tag pill (design tokens from spec §2.1/§2.2)

struct TagPillData: Identifiable {
    let id = UUID()
    let label: String
    let isAISourced: Bool
}

struct TagPill: View {
    let data: TagPillData

    var body: some View {
        HStack(spacing: 4) {
            if data.isAISourced {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
            }
            Text(data.label)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }

    // Swap .accentColor / .purple for the `tagBackground` / `aiAccent`
    // Asset Catalog colors (spec §2.2) once those are set up in the project.
    private var tint: Color {
        data.isAISourced ? .purple : .accentColor
    }
}

// MARK: - Row with overflow handling (max 3 visible, spec §1.1)

struct TagPillRow: View {
    let tags: [TagPillData]
    var maxVisible: Int = 3

    var body: some View {
        TagFlowLayout(spacing: 8) {
            ForEach(tags.prefix(maxVisible)) { tag in
                TagPill(data: tag)
            }
            if tags.count > maxVisible {
                TagPill(data: TagPillData(label: "+\(tags.count - maxVisible)", isAISourced: false))
            }
        }
    }
}

#Preview {
    TagPillRow(tags: [
        .init(label: "travel", isAISourced: false),
        .init(label: "reflection", isAISourced: true),
        .init(label: "morning pages", isAISourced: false),
        .init(label: "gratitude", isAISourced: true),
        .init(label: "work", isAISourced: false),
    ])
    .padding()
    .frame(width: 320, alignment: .leading)
}
