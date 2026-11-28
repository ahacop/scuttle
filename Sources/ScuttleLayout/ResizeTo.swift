import CoreGraphics

/// Resizing a window to a size, as a mouse drag on its edge does.
extension Workspace {
    /// Give the window's column the width of `size`; its neighbours keep theirs and move along. The height is the
    /// strip's, so it is not changed. Does nothing in fullscreen. False when nothing changed.
    @discardableResult
    public mutating func resize(_ id: WindowID, to size: CGSize) -> Bool {
        guard fullscreen == nil, let frame = tiledLayout().frames[id], let column = columns.firstIndex(of: id) else { return false }
        let delta = size.width - frame.width
        guard abs(delta) >= 0.5 else { return false }
        let area = stripArea, share = Double((columnSpans(in: area)[column].width + delta) / area.width)
        setWidth(ofColumn: column, share)
        reveal(id)
        return true
    }
}
