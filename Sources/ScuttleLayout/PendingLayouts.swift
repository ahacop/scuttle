/// Dirty workspaces coalesce while macOS presents an overview. Hidden workspaces wait for their Space.
public struct PendingLayouts {
    public var dirty: Set<UInt64> = []
    private var paused = false

    public init() {}

    public mutating func pause(_ interrupted: Set<UInt64>) {
        paused = true
        dirty.formUnion(interrupted)
    }

    /// Workspaces to snap on exit, including workspaces first changed while the overview was open.
    @discardableResult
    public mutating func resume() -> Set<UInt64> {
        paused = false
        return dirty
    }

    public mutating func take(visible: Set<UInt64>, existing: Set<UInt64>) -> Set<UInt64> {
        guard !paused else { return [] }
        let ready = dirty.intersection(visible).intersection(existing)
        dirty.formIntersection(existing.subtracting(visible))
        return ready
    }
}
