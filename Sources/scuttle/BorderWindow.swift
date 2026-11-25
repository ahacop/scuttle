import AppKit
import ScuttleConfig
import ScuttlePrivate

// The border of one window: scuttle-owned SkyLight windows, the two sides and the runs between them along the top
// and the bottom, kept directly below or above its target. Redraws only when the look or size changes; a plain move
// just re-places it, and a width on its way stretches the runs.
final class BorderWindow {
    struct Look: Equatable {
        var size: CGSize
        var cornerRadius: Int
        var color: ScuttleConfig.Color
        var width: Double

        /// The same look at another size.
        func with(size: CGSize) -> Look {
            var look = self
            look.size = size
            return look
        }

        /// The same shape in another colour.
        func with(color: ScuttleConfig.Color) -> Look {
            var look = self
            look.color = color
            return look
        }
    }

    private let target: UInt32
    /// The edge windows; all 0 until created.
    private var border = ScuttleBorder()
    private var created = false
    private var scale = 0.0
    private var spaceID: UInt64 = 0
    private var drawn: Look?
    private var isShown = false
    /// The window's size when the border was last tracked, to tell a size still changing from one that has arrived.
    private var tracked: CGSize?

    init(target: UInt32) {
        self.target = target
    }

    deinit {
        scuttle_border_destroy(&border)
    }

    /// Whether `id` is one of this border's own windows.
    func owns(_ id: UInt32) -> Bool { scuttle_border_owns(&border, id) }

    /// Place and draw the border around `window`, redrawn only when its look changed. During an animated resize
    /// this runs once a frame per window: a redraw costs about 2 ms more than a move (scripts/border-bench.sh), and a
    /// border hidden until its window arrived flickered off and on with every resize.
    ///
    /// A window whose size is on its way, as while its edge is dragged or macOS zooms it open, has its border
    /// stretched instead, as `track` does. False then: the border is not drawn for this size, and the caller asks
    /// again once the size has had time to hold.
    @discardableResult
    func update(_ window: Window, color: ScuttleConfig.Color, config: Borders) -> Bool {
        let look = Look(size: window.frame.size, cornerRadius: window.cornerRadius,
                        color: color, width: config.width)
        let scale = backingScale(of: window.frame)
        if scale != self.scale { recreate(scale: scale) }
        guard created else { return true }

        if spaceID != window.spaceID, window.spaceID != 0 {
            scuttle_border_move_to_space(&border, window.spaceID)
            spaceID = window.spaceID
        }
        let order: ScuttleBorderOrder = config.order == .above ? .above : .below
        if look == drawn {
            scuttle_border_move(&border, target, window.frame, config.width, order)
        } else if isShown, let drawn, look == drawn.with(color: color), Self.recolors {
            // Only the colour changed, as when focus moves: the pieces are redrawn where they are, then placed as
            // for a move.
            let rgba = ScuttleBorderColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            scuttle_border_recolor(&border, window.frame, Int32(window.cornerRadius), rgba, config.width)
            scuttle_border_move(&border, target, window.frame, config.width, order)
            self.drawn = look
        } else if isShown, let drawn, look == drawn.with(size: window.frame.size), tracked != window.frame.size, Self.stretches,
                  stretch(to: window, color: color, width: config.width) {
            tracked = window.frame.size
            return false
        } else {
            let rgba = ScuttleBorderColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            scuttle_border_update(&border, target, window.frame, Int32(window.cornerRadius), rgba, config.width, order)
            drawn = look
        }
        isShown = true
        tracked = window.frame.size
        return true
    }

    /// Moves the border to the window and stretches its runs to the window's size, in a transaction of its own.
    /// False if the border cannot follow as it is drawn.
    private func stretch(to window: Window, color: ScuttleConfig.Color, width: Double) -> Bool {
        guard let transaction = scuttle_border_transaction_create() else { return false }
        let rgba = ScuttleBorderColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        guard follow(window, rgba, width, in: transaction) else { return false }
        scuttle_border_transaction_commit(transaction)
        return true
    }

    /// Puts the border around the window in `transaction` as it is drawn, its runs stretched to the window's width
    /// and, if the height is another, its sides redrawn for it first. False if it cannot follow so.
    private func follow(_ window: Window, _ color: ScuttleBorderColor, _ width: Double, in transaction: CFTypeRef) -> Bool {
        let radius = Int32(window.cornerRadius)
        if scuttle_border_transaction_follow(transaction, &border, window.frame, radius, width) { return true }
        return scuttle_border_fit_sides(&border, window.frame, radius, color, width)
            && scuttle_border_transaction_follow(transaction, &border, window.frame, radius, width)
    }

    /// Keeps a shown border on a moving window, as part of a transaction moving several. A window at another width
    /// than the border was drawn for has its border stretched, which costs nothing to draw, until it arrives and
    /// `update` draws it for where it came to rest; redrawing it as soon as its width held for a frame, as it does
    /// at both ends of an ease, took 22 ms of the main thread two or three times a glide. Only a new look, or a size
    /// the border cannot be stretched to, has it redrawn here. It stays at the scale, on the Space and in the
    /// stacking it was drawn for, none of which a window mid-animation changes.
    func track(_ window: Window, color: ScuttleConfig.Color, config: Borders, in transaction: CFTypeRef) {
        guard created, isShown else { return }
        let look = Look(size: window.frame.size, cornerRadius: window.cornerRadius, color: color, width: config.width)
        let radius = Int32(window.cornerRadius)
        defer { tracked = window.frame.size }
        if look != drawn {
            let sizeOnly = drawn.map { $0.cornerRadius == look.cornerRadius && $0.color == look.color && $0.width == look.width } ?? false
            let rgba = ScuttleBorderColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            if sizeOnly, Self.stretches, follow(window, rgba, config.width, in: transaction) { return }
            scuttle_border_redraw_shape(&border, window.frame, radius, rgba, config.width, sizeOnly)
            drawn = look
        }
        _ = scuttle_border_transaction_follow(transaction, &border, window.frame, radius, config.width)
    }

    /// `SCUTTLE_BORDER_STRETCH=0` redraws a border for every new size of its window, as before, for comparing with
    /// scripts/anim.
    private static let stretches = ProcessInfo.processInfo.environment["SCUTTLE_BORDER_STRETCH"] != "0"

    /// Follows a window that only moved: the border keeps its shape, Space and place in the stacking, so it is moved
    /// without being redrawn or re-ordered. False if it needs `update` instead: it is hidden, or the window has a new
    /// size or reached a display of another scale.
    func follow(_ window: Window) -> Bool {
        guard isShown, let drawn, drawn.size == window.frame.size,
              backingScale(of: window.frame) == scale else { return false }
        scuttle_border_follow(&border, window.frame, drawn.width)
        return true
    }

    func hide() {
        guard isShown else { return }
        scuttle_border_hide(&border)
        isShown = false
    }

    // JankyBorders sets the resolution once, at creation; a display change gets a new window.
    // Widths and radii stay in points; the resolution alone decides the pixels.
    /// `SCUTTLE_BORDER_RECOLOR=0` reshapes and places a border for a new colour as for a new size, as before, for
    /// comparing with scripts/anim.
    private static let recolors = ProcessInfo.processInfo.environment["SCUTTLE_BORDER_RECOLOR"] != "0"

    private func recreate(scale: Double) {
        scuttle_border_destroy(&border)
        created = scuttle_border_create(&border, scale)
        self.scale = scale
        spaceID = 0
        drawn = nil
    }
}

// The backing scale of the screen under the frame's centre. Frames are top-left global,
// NSScreen frames bottom-left, flipped around the primary screen.
private func backingScale(of frame: CGRect) -> Double {
    let screens = NSScreen.screens
    guard let primary = screens.first else { return 2 }
    let center = CGPoint(x: frame.midX, y: primary.frame.maxY - frame.midY)
    let screen = screens.first { $0.frame.contains(center) } ?? primary
    return screen.backingScaleFactor
}
