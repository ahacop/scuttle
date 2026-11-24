// Calibrates the harness: glides one block of colour back and forth in ways whose smoothness is known, so the
// recording's own measures (cal.py) can be told from scuttle's. Usage:
//   animcal layer                    a layer animated by the render server inside a still window: as smooth as it gets
//   animcal window [delay ms]        a window that moves itself on every display frame
//   animcal target                   a plain window that waits to be moved
//   animcal ax <pid> [delay ms] [size|both]
//                                    moves (or resizes, or both) the target's window through Accessibility on every
//                                    display frame, as scuttle does, `delay` ms after the frame the link fired for
// Each makes ten glides of 200 ms, 1500 points, 0.5 s apart, then exits (the target is killed by cal.sh).
import AppKit
import ApplicationServices

let arguments = CommandLine.arguments
let mode = arguments.count > 1 ? arguments[1] : "layer"
let fill = NSColor(srgbRed: 0xd8 / 255.0, green: 0x1b / 255.0, blue: 0x60 / 255.0, alpha: 1)
let low = 200.0, high = 1700.0, duration = 0.2, pause = 0.5, glides = 10

/// Where the block's left edge is `t` seconds into the run, and whether the run is over.
func position(_ t: Double) -> (Double, Bool) {
    let n = Int(t / (duration + pause))
    if n >= glides { return (glides % 2 == 0 ? low : high, true) }
    let u = min(1, max(0, (t - Double(n) * (duration + pause) - pause) / duration))
    let e = 3 * u * u - 2 * u * u * u
    let (from, to) = n % 2 == 0 ? (low, high) : (high, low)
    return ((from + (to - from) * e).rounded(), false)
}

final class Driver: NSObject {
    var start: CFTimeInterval?
    var step: (Double) -> Void = { _ in }
    var delay = 0.0
    @objc func tick(_ link: CADisplayLink) {
        if delay > 0 {
            let wait = link.timestamp + delay - CACurrentMediaTime()
            if wait > 0 { Thread.sleep(forTimeInterval: wait) }
        }
        if start == nil { start = link.timestamp }
        let (x, done) = position(link.timestamp - start!)
        step(x)
        if done { exit(0) }
    }
}

final class SlowView: NSView {
    let drawDelay = (ProcessInfo.processInfo.environment["ANIMCAL_DRAW_MS"].flatMap(Double.init) ?? 0) / 1000
    override func draw(_ dirtyRect: NSRect) {
        if drawDelay > 0 { Thread.sleep(forTimeInterval: drawDelay) }
        fill.setFill()
        bounds.fill()
    }
}

let app = NSApplication.shared
let screen = NSScreen.main!
let driver = Driver()

func makeWindow(_ rect: CGRect, style: NSWindow.StyleMask, colour: NSColor) -> NSWindow {
    // Top-left points to AppKit's bottom-left.
    let frame = CGRect(x: rect.minX, y: screen.frame.height - rect.maxY, width: rect.width, height: rect.height)
    let window = NSWindow(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
    window.backgroundColor = colour
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    return window
}

switch mode {
case "layer":
    app.setActivationPolicy(.accessory)
    let window = makeWindow(CGRect(x: 0, y: 200, width: screen.frame.width, height: 600), style: [.borderless], colour: .black)
    window.level = .floating
    let view = NSView(frame: window.contentView!.bounds)
    view.wantsLayer = true
    window.contentView = view
    let block = CALayer()
    block.backgroundColor = fill.cgColor
    block.anchorPoint = .zero
    block.frame = CGRect(x: low, y: 0, width: 600, height: 600)
    view.layer!.addSublayer(block)
    var end = pause
    for n in 0..<glides {
        let (from, to) = n % 2 == 0 ? (low, high) : (high, low)
        DispatchQueue.main.asyncAfter(deadline: .now() + end) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            block.position = CGPoint(x: to, y: 0)
            CATransaction.commit()
            _ = from
        }
        end += duration + pause
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + end) { exit(0) }
case "window":
    app.setActivationPolicy(.accessory)
    let window = makeWindow(CGRect(x: low, y: 200, width: 600, height: 600), style: [.borderless], colour: fill)
    window.level = .floating
    driver.delay = (arguments.count > 2 ? Double(arguments[2]) ?? 0 : 0) / 1000
    driver.step = { x in window.setFrameOrigin(CGPoint(x: x, y: window.frame.minY)) }
    screen.displayLink(target: driver, selector: #selector(Driver.tick)).add(to: .main, forMode: .common)
case "target":
    app.setActivationPolicy(.regular)
    let window = makeWindow(CGRect(x: low, y: 200, width: 600, height: 600), style: [.titled, .resizable], colour: fill)
    window.title = "animcal"
    // `ANIMCAL_DRAW_MS` makes every redraw take that long, as an app with real contents does on a resize.
    let view = SlowView(frame: window.contentView!.bounds)
    view.autoresizingMask = [.width, .height]
    window.contentView = view
    app.activate(ignoringOtherApps: true)
    _ = window
case "ax":
    guard AXIsProcessTrusted() else { print("animcal: no Accessibility permission"); exit(2) }
    let pid = pid_t(arguments[2])!
    driver.delay = (arguments.count > 3 ? Double(arguments[3]) ?? 0 : 0) / 1000
    let what = arguments.count > 4 ? arguments[4] : "move"
    let target = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(target, kAXWindowsAttribute as CFString, &value) == .success,
          let element = (value as? [AXUIElement])?.first else { print("animcal: no window"); exit(3) }
    // Off the main thread, as scuttle steps.
    let thread = Thread {
        var ticks = 0
        driver.step = { x in
            // `size` grows the window rightwards in place; `both` keeps its right edge still, as a column pushed
            // from the left would; `move` only moves it. `first` moves it, with its unchanged size written before
            // and after on the first tick only, as scuttle's first step of a glide does; `same` on every tick.
            ticks += 1
            var origin = CGPoint(x: what == "size" ? low : x, y: 200)
            var size = CGSize(width: what == "size" ? 600 + (x - low) / 2 : what == "both" ? 600 + (high - x) / 2 : 600, height: 600)
            let sized = what == "size" || what == "both" || what == "same" || (what == "first" && ticks == 1)
            if sized { AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!) }
            if what != "size" { AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &origin)!) }
            if what == "same" || (what == "first" && ticks == 1) {
                AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
            }
        }
        screen.displayLink(target: driver, selector: #selector(Driver.tick)).add(to: .current, forMode: .common)
        RunLoop.current.run()
    }
    thread.qualityOfService = .userInteractive
    thread.start()
default:
    print("animcal: unknown mode \(mode)")
    exit(1)
}
app.run()
