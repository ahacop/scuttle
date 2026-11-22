import AppKit
import CoreGraphics
import ScuttleConfig
import Foundation

/// One key-down event tap with the config's bindings. A bound key is swallowed and its command list
/// handed to `onCommands`, except in apps excluded by that binding; anything else passes through
/// untouched.
final class HotkeyEngine {
    private let onCommands: ([String]) -> Void
    private var bindings: [KeyPress: KeyBinding] = [:]
    private var sides = ModifierSides()
    var enabled = true
    private var tap: CFMachPort?

    /// `onCommands` is called on the main queue with the binding's commands, in order.
    init(onCommands: @escaping ([String]) -> Void) {
        self.onCommands = onCommands
    }

    /// Replaces all bindings.
    func load(_ bindings: Bindings, sides: ModifierSides) {
        self.sides = sides
        self.bindings = Dictionary(uniqueKeysWithValues: bindings.bindings.map { (KeyPress($0.key), $0.value) })
    }

    /// Creates the tap on the current run loop, unless it exists. False if it could not (Accessibility missing);
    /// the caller reports that, since it tries again.
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: hotkeyCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    /// The commands bound to this event, if scuttle should take it.
    fileprivate func commands(for event: CGEvent) -> [String]? {
        guard enabled, let press = KeyPress(event, sides: sides) else { return nil }
        guard let binding = bindings[press],
              binding.applies(to: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return nil }
        return binding.commands
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, let commands = commands(for: event) else { return Unmanaged.passUnretained(event) }
        // Run the commands after the callback returns, so slow commands never time the tap out.
        DispatchQueue.main.async { self.onCommands(commands) }
        return nil
    }
}

private func hotkeyCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<HotkeyEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}
