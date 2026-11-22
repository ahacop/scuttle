import Foundation
import TOMLDecoder

// Config types and TOML loading. No AppKit here; Carbon.HIToolbox for the key codes only.
// TOML keys are kebab-case, Swift properties camelCase. Every key is optional; the defaults are the
// property initial values, and the shipped file (DefaultConfig.swift) spells out the same values.

public struct Config: Equatable {
    public var startAtLogin = true
    /// Workspaces across all displays, numbered from 1. Each is one native Space.
    public var workspaces = 5
    /// `[workspace-to-display]`: by workspace number, the display patterns it lives on, the first that matches
    /// a connected display winning. Other workspaces, and these when no pattern matches, live on the main display.
    public var workspaceDisplays: [Int: [MonitorPattern]] = [:]
    /// Renumber workspaces when their Spaces are reordered, rather than moving windows back to keep the numbers.
    public var followSpaceOrder = false
    /// Whether danky tiles numbered workspaces unless overridden.
    public var defaultTiling = true
    /// Workspace numbers (1-based) with their own tiling settings, resolved against the top-level defaults.
    public var workspaceLayouts: [Int: WorkspaceSettings] = [:]
    /// Cmd-Tab and Dock clicks go through the fast switch.
    public var followAppActivation = FollowAppActivation()
    /// Float standard windows whose fullscreen button is missing or disabled, as AeroSpace does.
    public var floatWindowsWithoutFullscreen = true
    /// Bring windows straight back out of macOS's native full screen, showing them with danky's `fullscreen`
    /// on their workspace instead, so every window stays on a danky workspace.
    public var blockNativeFullscreen = true
    /// The share of the width inside the outer gaps a fullscreen window takes, centred.
    /// 1 fills the width. `[display.<pattern>]` and workspace tables override it.
    public var fullscreenWidth = 1.0
    /// A lone window's share, or nil to use the resolved fullscreen width.
    public var loneWindowWidth: Double?
    public var accordion = Accordion()
    public var scrolling = Scrolling()
    public var gaps = Gaps()
    /// `[display.<pattern>]` overrides, in file order.
    public var displays: [DisplayOverride] = []
    public var borders = Borders()
    public var focusFollowsMouse = FocusFollowsMouse()
    public var swipe = Swipe()
    public var animations = Animations()
    public var drag = Drag()
    public var modifiers = ModifierSides()
    public var hooks = Hooks()
    /// `[[rules]]`, in file order.
    public var rules: [WindowRule] = []
    /// Keyed by mode name, e.g. `main`, `service`.
    public var modes: [String: Mode] = [:]
    /// Non-fatal config problems found while parsing.
    public var warnings: [ConfigWarning] = []

    public init() {}

    /// `~/.config/danky/danky.toml`
    public static var userConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/danky/danky.toml")
    }

    /// The config shipped with danky, used when the user has none.
    public static let `default` = try! parse(defaultTOML)

    /// Write the default config to `url`, creating its folder, if there is nothing there yet. A symlink counts
    /// even when what it points to is missing, such as a dotfiles checkout not cloned yet: writing would replace it.
    public static func writeDefaultIfMissing(at url: URL) {
        // Unlike fileExists, attributesOfItem describes a symlink itself rather than following it.
        guard (try? FileManager.default.attributesOfItem(atPath: url.path)) == nil else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (defaultTOML + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    public static func load(from url: URL) throws(ConfigError) -> Config {
        let toml: String
        do {
            toml = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigError("can't read \(url.path): \(error.localizedDescription)")
        }
        return try parse(toml)
    }

    /// Only changed border settings bypass window updates; an unchanged reload still retries arrangement.
    public func requiresWindowUpdate(comparedTo previous: Config) -> Bool {
        guard borders != previous.borders else { return true }
        var nonDecoration = self
        nonDecoration.borders = previous.borders
        return nonDecoration != previous
    }

    public static func parse(_ toml: String) throws(ConfigError) -> Config {
        let root: TOMLTable
        do {
            root = try TOMLTable(source: toml)
        } catch {
            // Syntax errors; TOMLDecoder's text already carries the line.
            throw ConfigError("\(error)")
        }
        do {
            let table = Table(root)
            var config = try Config(table)
            config.warnings = table.warningSink.warnings.map { warning in
                var warning = warning
                warning.line = warning.line ?? lineNumber(of: warning.path, in: toml)
                return warning
            }
            return config
        } catch let error as ConfigError {
            var error = error
            error.line = error.line ?? lineNumber(of: error.path, in: toml)
            throw error
        } catch {
            throw ConfigError("\(error)")
        }
    }

    init(_ t: Table) throws {
        startAtLogin = try t.bool("start-at-login") ?? startAtLogin
        workspaces = try t.int("workspaces") ?? workspaces
        guard workspaces >= 1 else { throw ConfigError(path: "workspaces", "must be at least 1") }
        if let assignments = try t.table("workspace-to-display") {
            // `01` and `+1` name workspace 1 too, as they always have, with a warning. When several keys name one
            // workspace, the last in the file wins, as it always has, and the others are ignored with a warning.
            var winningKeys: [Int: String] = [:]
            var keyCounts: [Int: Int] = [:]
            for key in assignments.keys {
                guard let n = Int(key), (1...workspaces).contains(n) else {
                    throw ConfigError(path: assignments.path(key), "'\(key)' is not a workspace number from 1 to \(workspaces)")
                }
                winningKeys[n] = key
                keyCounts[n, default: 0] += 1
            }
            for key in assignments.keys {
                let n = Int(key)!
                let patterns = try assignments.stringOrStrings(key)!
                guard !patterns.isEmpty, !patterns.contains("") else {
                    throw ConfigError(path: assignments.path(key), "a display pattern can't be empty")
                }
                guard winningKeys[n] == key else {
                    assignments.warn(key, "ignored: workspace \(n) is set again by '\(winningKeys[n]!)'")
                    continue
                }
                // While another key names the same workspace, renaming could repeat a key, which TOML rejects, so
                // the fix waits until the ignored key is gone.
                if String(n) != key {
                    let fix = keyCounts[n] == 1 ? ConfigFix(replace: key, with: String(n)) : nil
                    assignments.warn(key, "'\(key)' is workspace \(n); write it as '\(n)'", fix: fix)
                }
                workspaceDisplays[n] = patterns.map(MonitorPattern.init)
            }
            try assignments.done()
        }
        followSpaceOrder = try t.bool("follow-space-order") ?? followSpaceOrder
        defaultTiling = try t.bool("default-tiling") ?? defaultTiling
        if let workspacesTable = try t.table("workspace") {
            for number in workspacesTable.keys {
                guard let index = Int(number), index > 0, String(index) == number else {
                    throw ConfigError(path: workspacesTable.path(number), "expected a positive workspace number")
                }
                workspaceLayouts[index] = try WorkspaceSettings(workspacesTable.table(number)!,
                                                                base: WorkspaceSettings(tiling: defaultTiling))
            }
        }
        followAppActivation = try FollowAppActivation(t, "follow-app-activation") ?? followAppActivation
        floatWindowsWithoutFullscreen = try t.bool("float-windows-without-fullscreen") ?? floatWindowsWithoutFullscreen
        blockNativeFullscreen = try t.bool("block-native-fullscreen") ?? blockNativeFullscreen
        fullscreenWidth = try t.windowWidth("fullscreen-width") ?? fullscreenWidth
        loneWindowWidth = try t.windowWidth("lone-window-width")
        accordion = try t.table("accordion").map(Accordion.init) ?? accordion
        scrolling = try t.table("scrolling").map(Scrolling.init) ?? scrolling
        gaps = try t.table("gaps").map { try gaps.applying(GapsPatch($0)) } ?? gaps
        if let displayTable = try t.table("display") {
            for pattern in displayTable.keys {
                displays.append(try DisplayOverride(pattern, displayTable.table(pattern)!))
            }
        }
        borders = try t.table("borders").map(Borders.init) ?? borders
        focusFollowsMouse = try t.table("focus-follows-mouse").map(FocusFollowsMouse.init) ?? focusFollowsMouse
        swipe = try t.table("swipe").map(Swipe.init) ?? swipe
        animations = try t.table("animations").map(Animations.init) ?? animations
        drag = try t.table("drag").map(Drag.init) ?? drag
        modifiers = try t.table("modifiers").map(ModifierSides.init) ?? modifiers
        hooks = try t.table("hooks").map(Hooks.init) ?? hooks
        rules = try t.tables("rules")?.map(WindowRule.init) ?? []
        if let modeTable = try t.table("mode") {
            for name in modeTable.keys {
                modes[name] = try Mode(modeTable.table(name)!)
            }
        }
        try t.done()
    }
}

/// A workspace's tiling settings: a `[workspace.N]` table with omitted keys taken from the top-level settings,
/// or a `[workspace.N.display.<pattern>]` table with omitted keys taken from its workspace's.
public struct WorkspaceSettings: Equatable {
    public var tiling: Bool
    /// `fullscreen-width` from this table or the workspace's it inherits from; nil leaves it to the display's or
    /// the top-level value. See `Config.fullscreenWidth(forWorkspace:on:)`.
    public var fullscreenWidth: Double?
    /// A lone window's share from this table or its workspace, before display and top-level resolution.
    public var loneWindowWidth: Double?
    /// `[workspace.N.display.<pattern>]`: the settings that replace these on the displays a pattern matches,
    /// in file order.
    public var displays: [WorkspaceOnDisplay] = []

    public init(tiling: Bool) {
        self.tiling = tiling
    }

    /// Display tables are read only in a workspace's own table, not nested in one another.
    init(_ t: Table, base: WorkspaceSettings, readsDisplays: Bool = true) throws {
        self = base
        displays = []
        tiling = try t.bool("tiling") ?? tiling
        fullscreenWidth = try t.windowWidth("fullscreen-width") ?? fullscreenWidth
        loneWindowWidth = try t.windowWidth("lone-window-width") ?? loneWindowWidth
        if readsDisplays, let displayTable = try t.table("display") {
            for pattern in displayTable.keys {
                guard !pattern.isEmpty else { throw ConfigError(path: displayTable.path, "a display pattern can't be empty") }
                let settings = try WorkspaceSettings(displayTable.table(pattern)!, base: self, readsDisplays: false)
                displays.append(WorkspaceOnDisplay(pattern: MonitorPattern(pattern), settings: settings))
            }
        }
        try t.done()
    }
}

/// One `[workspace.N.display.<pattern>]` table.
public struct WorkspaceOnDisplay: Equatable {
    public var pattern: MonitorPattern
    public var settings: WorkspaceSettings
}

extension Config {
    /// The settings of the workspace with this number, the top-level ones for an unnumbered workspace. On
    /// `monitor`, the workspace's most specific matching display table replaces them, the last of equals winning.
    public func settings(forWorkspace number: Int?, on monitor: Monitor? = nil) -> WorkspaceSettings {
        let settings = number.flatMap { workspaceLayouts[$0] } ?? WorkspaceSettings(tiling: defaultTiling)
        guard let monitor else { return settings }
        var best: WorkspaceOnDisplay?
        for display in settings.displays where display.pattern.matches(monitor)
            && display.pattern.specificity >= best?.pattern.specificity ?? .min {
            best = display
        }
        return best?.settings ?? settings
    }

    /// The share of the width a fullscreen window takes on the workspace with this number on
    /// `monitor`: the workspace's own tables' value, else the most specific matching `[display.<pattern>]`'s, else
    /// the top-level `fullscreen-width`.
    public func fullscreenWidth(forWorkspace number: Int?, on monitor: Monitor? = nil) -> Double {
        if let width = settings(forWorkspace: number, on: monitor).fullscreenWidth { return width }
        guard let monitor else { return fullscreenWidth }
        return overrides(for: monitor).last { $0.fullscreenWidth != nil }?.fullscreenWidth ?? fullscreenWidth
    }

    /// Resolve the lone-window share independently, falling back only after every level has been checked.
    public func loneWindowWidth(forWorkspace number: Int?, on monitor: Monitor? = nil) -> Double {
        if let width = settings(forWorkspace: number, on: monitor).loneWindowWidth { return width }
        if let monitor, let width = overrides(for: monitor).last(where: { $0.loneWindowWidth != nil })?.loneWindowWidth {
            return width
        }
        return loneWindowWidth ?? fullscreenWidth(forWorkspace: number, on: monitor)
    }
}

extension Table {
    /// Window widths share the same range at every level of the config.
    func windowWidth(_ key: String) throws -> Double? {
        guard let width = try double(key) else { return nil }
        guard (0.1...1).contains(width) else { throw ConfigError(path: path(key), "must be 0.1 to 1") }
        return width
    }
}

public struct Accordion: Equatable {
    /// Points by which neighbouring windows peek out.
    public var padding = 30

    public init() {}

    init(_ t: Table) throws {
        padding = try t.int("padding") ?? padding
        if padding < 0 {
            // Older danky loaded a negative padding as written, so it still does.
            t.warn("padding", "should be 0 or more; still read as \(padding)",
                   fix: ConfigFix(replace: String(padding), with: "0"))
        }
        try t.done()
    }
}

/// `[scrolling]`: the strip's columns.
public struct Scrolling: Equatable {
    /// A new column's width, as a share of the display's width inside the outer gaps. niri's default is half.
    public var columnWidth = 0.5
    /// The widths `switch-preset-column-width` steps through, as shares, sorted narrowest first. niri's default
    /// thirds.
    public var presetColumnWidths = [0.33333, 0.5, 0.66667]

    public init() {}

    init(_ t: Table) throws {
        columnWidth = try t.double("column-width") ?? columnWidth
        guard (0.1...1).contains(columnWidth) else { throw ConfigError(path: t.path("column-width"), "must be 0.1 to 1") }
        if let presets: [Double] = try t.doubles("preset-column-widths") {
            guard !presets.isEmpty else { throw ConfigError(path: t.path("preset-column-widths"), "needs at least one width") }
            guard presets.allSatisfy({ (0.1...1).contains($0) }) else {
                throw ConfigError(path: t.path("preset-column-widths"), "every width must be 0.1 to 1")
            }
            presetColumnWidths = presets.sorted()
        }
        try t.done()
    }
}

/// Below the target, or above it as a ring that never covers content or takes clicks.
public enum BorderOrder: String, CaseIterable {
    case below, above
}

public struct Borders: Equatable {
    public var enabled = true
    public var width = 4.0
    public var activeColor = try! Color(hex: "#e1e3e4")
    public var inactiveColor = try! Color(hex: "#494d64")
    public var order = BorderOrder.below
    /// Bundle IDs whose windows get no border.
    public var excludeApps: [String] = []
    public var rules: [BorderRule] = []

    public init() {}

    init(_ t: Table) throws {
        enabled = try t.bool("enabled") ?? enabled
        width = try t.double("width") ?? width
        if !width.isFinite {
            let defaultWidth = Borders().width
            let token = width.isNaN ? "nan" : "inf"
            let replacement = width.sign == .minus ? "-\(token)" : token
            width = defaultWidth
            t.warn("width", "must be a finite number, 0 or more; using the default, \(configNumber(defaultWidth))",
                   fix: ConfigFix(replace: replacement, with: configNumber(defaultWidth)))
        } else if width < 0 {
            // Older danky loaded a negative width as written, so it still does.
            let written = configNumber(width)
            t.warn("width", "should be 0 or more; still read as \(written)", fix: ConfigFix(replace: written, with: "0"))
        }
        activeColor = try t.color("active-color") ?? activeColor
        inactiveColor = try t.color("inactive-color") ?? inactiveColor
        order = try t.choice("order") ?? order
        excludeApps = try t.strings("exclude-apps") ?? excludeApps
        rules = try t.tables("rules")?.map(BorderRule.init) ?? []
        try t.done()
    }

    /// Global disable and app exclusions veto even an explicit per-window enable.
    public func decorates(bundleID: String?, appName: String?, title: String, kind: WindowKind?, identifier: String?) -> Bool {
        guard enabled, decorates(bundleID: bundleID) else { return false }
        return rules.last { $0.match.matches(appId: bundleID, appName: appName, title: title, kind: kind,
                                             windowIdentifier: identifier) }?.enabled ?? true
    }

    /// Whether windows of the app with this bundle ID get a border.
    public func decorates(bundleID: String?) -> Bool {
        !(bundleID.map(excludeApps.contains) ?? false)
    }
}

/// A number as a config would write it: `-2` rather than `-2.0`, so a fix's text also matches `-2` in the file.
private func configNumber(_ value: Double) -> String {
    if let integer = Int(exactly: value) { return String(integer) }
    return String(value)
}

/// `follow-app-activation = true`, or a table for apps not to follow.
public struct FollowAppActivation: Equatable {
    public var enabled = true
    /// Bundle IDs whose activation is not followed, such as a menu bar app whose popover counts as a window.
    public var excludeApps: [String] = []

    public init() {}

    init(_ t: Table) throws {
        enabled = try t.bool("enabled") ?? enabled
        excludeApps = try t.strings("exclude-apps") ?? excludeApps
        try t.done()
    }

    /// `key` in `parent` as written, `true`, `false` or a table; nil when it is absent.
    init?(_ parent: Table, _ key: String) throws {
        if parent.isTable(key) {
            try self.init(parent.table(key)!)
        } else if let enabled = try parent.bool(key) {
            self.init()
            self.enabled = enabled
        } else {
            return nil
        }
    }

    /// Whether activating the app with this bundle ID switches to its Space.
    public func follows(bundleID: String?) -> Bool {
        !(bundleID.map(excludeApps.contains) ?? false)
    }
}

public struct FocusFollowsMouse: Equatable {
    public var enabled = false
    /// How long the pointer must rest on a window before it takes focus.
    public var delayMs = 100
    /// Whether resting on the peeking edge of an accordion child focuses it. Off, only the front child does.
    public var accordionEdges = true

    public init() {}

    init(_ t: Table) throws {
        enabled = try t.bool("enabled") ?? enabled
        delayMs = try t.int("delay-ms") ?? delayMs
        guard delayMs >= 0 else { throw ConfigError(path: t.path("delay-ms"), "must be 0 or more") }
        accordionEdges = try t.bool("accordion-edges") ?? accordionEdges
        try t.done()
    }
}

/// `[swipe]`: the trackpad swipe that switches Spaces (three fingers, or four if macOS is set so) moves focus
/// between a tiled workspace's windows first, and switches Space only past the last one.
public struct Swipe: Equatable {
    public var enabled = false
    /// How a swipe past the last window switches Space.
    public var spaceSwitch = SpaceSwitch.instant
    /// Whether the swipe up and down, Mission Control's and App Exposé's, focuses the windows below and above first.
    public var vertical = false

    public init() {}

    init(_ t: Table) throws {
        enabled = try t.bool("enabled") ?? enabled
        spaceSwitch = try t.choice("space-switch") ?? spaceSwitch
        vertical = try t.bool("vertical") ?? vertical
        try t.done()
    }
}

/// `instant`: before macOS 27, danky owns the swipe and switches past the edge once the fingers lift.
/// `native`: macOS receives the whole swipe, so a full swipe can both move focus and switch Space.
/// On macOS 27+, instant falls back to native; attached IOHID payload suppression is not validated.
public enum SpaceSwitch: String, CaseIterable {
    case instant, native
}

/// `[animations]`: windows glide to their tiles instead of jumping. Off while macOS's Reduce Motion is on.
/// How a window's size changes while it glides to its tile.
public enum ResizeAnimation: String, CaseIterable {
    /// The size is set once, at the start, and only the position glides: smooth in every app.
    case instant
    /// The size glides with the position, one new size a frame: smooth only in apps that redraw that fast.
    case glide
}

public struct Animations: Equatable {
    public var enabled = true
    /// Roughly how long a window takes to reach its tile. 0 jumps, as with animations off.
    public var durationMs = 200
    public var resize = ResizeAnimation.instant

    public init() {}

    init(_ t: Table) throws {
        enabled = try t.bool("enabled") ?? enabled
        durationMs = try t.int("duration-ms") ?? durationMs
        guard (0...1000).contains(durationMs) else { throw ConfigError(path: t.path("duration-ms"), "must be 0 to 1000") }
        resize = try t.choice("resize") ?? resize
        try t.done()
    }
}

/// `[drag]`: dragging a tiled window with the mouse.
public struct Drag: Equatable {
    /// Outline the tile a dragged window came from and the one it will swap with.
    public var placeholders = true

    public init() {}

    init(_ t: Table) throws {
        placeholders = try t.bool("placeholders") ?? placeholders
        try t.done()
    }
}

/// Which of a modifier's two keys bindings answer to.
public enum ModifierSide: String, CaseIterable {
    case both, left, right
}

/// `[modifiers]`: a modifier limited to one side is only a binding's modifier from that side's key; the other
/// key types as usual, so right Option can still make special characters while left Option drives danky.
public struct ModifierSides: Equatable {
    public var alt = ModifierSide.both
    public var ctrl = ModifierSide.both
    public var cmd = ModifierSide.both
    public var shift = ModifierSide.both

    public init() {}

    init(_ t: Table) throws {
        alt = try t.choice("alt") ?? alt
        ctrl = try t.choice("ctrl") ?? ctrl
        cmd = try t.choice("cmd") ?? cmd
        shift = try t.choice("shift") ?? shift
        try t.done()
    }
}

/// `[hooks]`: danky commands run on events. Each is a command string or a list, empty by default.
public struct Hooks: Equatable {
    /// Once, after danky has first read the windows and displays.
    public var startup: [String] = []
    /// When danky starts switching a display to a workspace, or a switch in flight gets a new target.
    public var workspaceChanging: [String] = []
    /// When a display's current workspace changes, by danky or natively, and when a danky switch gives up.
    public var workspaceChanged: [String] = []
    /// When the focused window changes.
    public var focusChanged: [String] = []
    /// When the binding mode changes.
    public var modeChanged: [String] = []
    /// When a display connects or disconnects.
    public var displayChanged: [String] = []

    public init() {}

    init(_ t: Table) throws {
        startup = try t.commands("startup", allowEmpty: true) ?? startup
        workspaceChanging = try t.commands("workspace-changing", allowEmpty: true) ?? workspaceChanging
        workspaceChanged = try t.commands("workspace-changed", allowEmpty: true) ?? workspaceChanged
        focusChanged = try t.commands("focus-changed", allowEmpty: true) ?? focusChanged
        modeChanged = try t.commands("mode-changed", allowEmpty: true) ?? modeChanged
        displayChanged = try t.commands("display-changed", allowEmpty: true) ?? displayChanged
        try t.done()
    }
}
