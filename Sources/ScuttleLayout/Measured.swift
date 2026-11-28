import CoreGraphics

// A column is as wide as its window is. macOS has no way to ask what sizes a window can take, so a column asks its
// window for its share of the strip and takes the answer: narrower, wider or snapped to a grid, the neighbours are
// placed from where the window ends, not from where it was meant to.
//
// The answer is kept for the question it answered only: this window, at this share of this display, until a
// command gives the column another width. Coming back to the same width asks afresh too (`setWidth`), so an answer
// that was a passing state of the window lasts no longer than the next command. VMware shows why: it sizes its
// guest to the part of the window that is on screen and then snaps the window to the guest, so what it answers
// depends on where it stood when it was asked. Nothing is inferred about other widths, as a
// minimum size would be: columns do not share space, so no column needs to know what another could shrink to.
//
// An app slow to resize reads back at its old size and is taken at its word for a moment. It says so itself when
// it arrives: `observe` then forgets the answer.

/// What a window answered when asked for its column's width.
struct Measure: Equatable, Sendable {
    /// The column's share and the width of the workspace it was asked at.
    var share: Double
    var within: CGFloat
    /// How wide the window was.
    var got: CGFloat
    /// How many times the window answered the answer itself with another width. A window that never takes the
    /// width it reports is left alone after a few.
    var revisions = 0
}

extension Workspace {
    /// The window's answer to what its column asks of it now, if it gave another width than asked.
    func measure(of id: WindowID) -> Measure? {
        guard let measure = measured[id], abs(measure.share - (columnWidths[id] ?? columnWidth)) < 1e-9,
              measure.within == gaps.inset(bounds).width else { return nil }
        return measure
    }

    /// Whether the window is shown as its column: not fullscreen, and not a lone window narrowed.
    private func showsColumn(_ id: WindowID) -> Bool {
        guard fullscreen != id, let shown = layout().frames[id], let tile = tiledLayout().frames[id] else { return false }
        return shown.width == tile.width
    }

    /// A write asked the window to be `asked` wide and it read back `got` wide, where it was put. Another width
    /// than asked becomes its column's. An answer to a width the column no longer asks for says nothing.
    /// True when the layout changed.
    @discardableResult
    public mutating func measure(_ id: WindowID, asked: CGFloat, got: CGFloat) -> Bool {
        guard let column = columns.firstIndex(of: id), showsColumn(id) else { return false }
        let intended = intendedWidth(ofColumn: column, in: stripArea), known = measure(of: id)
        // Edges are rounded to whole points after the strip is scrolled, so a tile can be a point off its width.
        guard abs(asked - (known?.got ?? intended)) <= 1.5, abs(got - asked) > 2 else { return false }
        let revisions = known.map { $0.revisions + 1 } ?? 0
        guard revisions < 3 else { return false }
        measured[id] = abs(got - intended) <= 2 ? nil
            : Measure(share: width(ofColumn: column), within: gaps.inset(bounds).width, got: got, revisions: revisions)
        return true
    }

    /// The window changed its width by itself to `width`. If its column was going by an earlier answer, that no
    /// longer describes it: an app slow to resize has arrived, or it has gone somewhere else. Its column asks for
    /// its share again. True when the layout changed.
    @discardableResult
    public mutating func observe(_ id: WindowID, width: CGFloat) -> Bool {
        guard showsColumn(id), let known = measure(of: id), abs(width - known.got) > 2 else { return false }
        measured[id] = nil
        return true
    }

    /// Forgets every answer, so each window is asked for its column's share again.
    public mutating func forgetMeasures() { measured = [:] }

    /// For each window whose column goes by its answer: the width asked and the width it gave.
    public var measuredWidths: [WindowID: (asked: CGFloat, got: CGFloat)] {
        let area = stripArea
        return Dictionary(uniqueKeysWithValues: columns.indices.compactMap { i in
            measure(of: columns[i]).map { (columns[i], (intendedWidth(ofColumn: i, in: area), $0.got)) }
        })
    }
}
