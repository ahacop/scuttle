import Foundation

/// How animation steps are timed and written. The environment overrides each setting, so that scripts/anim can
/// record builds that differ in nothing else (`ab.sh`'s `::--env ...`). `init()` has everything off, for tests;
/// the app runs with `shared`: sizes within `snapWithin` points snap, and steps write only what changed. Both were
/// measured on screen (issue 24): swapping two columns whose widths differ by a few points went from some 24
/// repeated frames to 3 to 5. The delay, the aligned start and the lead showed no gain there and stay off.
struct AnimationTuning {
    /// `SCUTTLE_STEP_DELAY_MS`: each step waits until this long after the display frame its tick was for, so its
    /// writes reach the apps away from the start of the frame, when an app that is drawing answers late. Seconds.
    var stepDelay = 0.0
    /// `SCUTTLE_ALIGN_START`: a display link's first tick, part of the way into a frame, is not stepped on.
    var alignsStart = false
    /// `SCUTTLE_SNAP_RESIZE_WITHIN`: a size that changes by no more than this many points is taken at once
    /// while the position glides, as `resize = 'instant'` does for every size: glided, it is a point a frame, each
    /// one a redraw for the app, for a difference nobody sees. 0 glides every size.
    var snapResizeWithin = 0.0
    static let snapWithin = 16.0
    /// `SCUTTLE_RESIZE_LEAD`: how many display frames ahead a window whose size glides is asked for its frame.
    var resizeLead = 0.0
    /// A step writes only the position or size that changed since the last; `SCUTTLE_STEP_WRITES=all` has a
    /// resized window written size, position, size on every step, as before.
    var stepsWriteChanges = false

    static let shared = AnimationTuning(environment: ProcessInfo.processInfo.environment)

    init() {}

    init(environment: [String: String]) {
        func number(_ key: String) -> Double { max(0, environment[key].flatMap(Double.init) ?? 0) }
        stepDelay = min(number("SCUTTLE_STEP_DELAY_MS"), 15) / 1000
        alignsStart = number("SCUTTLE_ALIGN_START") > 0
        snapResizeWithin = environment["SCUTTLE_SNAP_RESIZE_WITHIN"] == nil ? Self.snapWithin : number("SCUTTLE_SNAP_RESIZE_WITHIN")
        resizeLead = min(number("SCUTTLE_RESIZE_LEAD"), 4)
        stepsWriteChanges = environment["SCUTTLE_STEP_WRITES"] != "all"
    }
}
