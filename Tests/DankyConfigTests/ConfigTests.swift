import Foundation
import Testing
@testable import DankyConfig

struct ConfigTests {
    @Test func `The configuration page shows the default config as danky writes it`() throws {
        let page = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "docs/configuration.md")
        let text = try String(contentsOf: page, encoding: .utf8)
        let section = try #require(text.range(of: "## Default config\n"))
        let open = try #require(text.range(of: "```toml\n", range: section.upperBound..<text.endIndex))
        let close = try #require(text.range(of: "\n```", range: open.upperBound..<text.endIndex))
        #expect(String(text[open.upperBound..<close.lowerBound]) == Config.defaultTOML)
    }

    @Test func `Default config loads`() throws {
        let config = try Config.parse(Config.defaultTOML)
        #expect(config == Config.default)
        #expect(config.startAtLogin)
        #expect(config.workspaces == 5)
        #expect(!config.followSpaceOrder)
        #expect(config.defaultTiling)
        #expect(config.followAppActivation == FollowAppActivation())
        #expect(config.floatWindowsWithoutFullscreen)
        #expect(config.gaps == Gaps())
        #expect(config.displays == [])
        #expect(config.borders.enabled)
        #expect(config.borders.width == 4)
        #expect(config.borders.activeColor == Color(red: 0xE1 / 255, green: 0xE3 / 255, blue: 0xE4 / 255))
        #expect(config.hooks == Hooks())
        #expect(config.rules.count == 1)
        #expect(config.rules[0].match.appId == "com.apple.systempreferences")
        #expect(config.rules[0].run == ["layout floating"])
        let main = config.bindings.bindings
        #expect(try main[KeyCombo("ctrl-left")]?.commands == ["workspace prev"])
        #expect(try main[KeyCombo("alt-9")]?.commands == ["workspace 9"])
        #expect(try main[KeyCombo("alt-shift-9")]?.commands == ["move-window-to-workspace 9"])
        #expect(try main[KeyCombo("alt-l")]?.commands == ["focus right"])
        #expect(try main[KeyCombo("alt-j")]?.commands == ["workspace next"], "workspaces stack top to bottom")
        #expect(try main[KeyCombo("alt-shift-k")]?.commands == ["move-window-to-workspace prev --follow"])
        #expect(try main[KeyCombo("alt-shift-l")]?.commands == ["move right"])
        #expect(try main[KeyCombo("alt-r")]?.commands == ["switch-preset-column-width"])
        #expect(try main[KeyCombo("alt-f")]?.commands == ["maximize-column"])
        #expect(try main[KeyCombo("alt-shift-f")]?.commands == ["fullscreen"])
        #expect(main.count == 36)
        #expect(config.blockNativeFullscreen)
    }

    @Test func `Shipped file is the defaults plus rules and bindings`() throws {
        var shipped = Config.default
        shipped.rules = []
        shipped.bindings = Bindings()
        #expect(shipped == Config(), "a key left out of a user's file must mean what the shipped file says")
    }

    @Test func `Empty config uses defaults`() throws {
        #expect(try Config.parse("") == Config())
    }

    @Test func `Warnings record nested paths and source lines`() throws {
        let config = try Config.parse("[display.main.gaps]\ninner = -3\n")
        #expect(config.warnings == [ConfigWarning(path: "display.main.gaps.inner",
                                                "should be 0 or more; still read as -3", line: 2,
                                                fix: ConfigFix(replace: "-3", with: "0"))])
    }

    @Test func `Warnings and errors count a CRLF line break as one line`() throws {
        let config = try Config.parse("[gaps]\r\ninner = -1\r\n")
        #expect(config.warnings.map(\.line) == [2])
        assertError("[scrolling]\r\ncolumn-width = 1.5\r\n", path: "scrolling.column-width", line: 2, contains: "0.1 to 1")
        assertError("workspaces = 5\r\n\r\n[gaps]\r\nouter = 'wide'\r\n", path: "gaps.outer", line: 4, contains: "expected")
    }

    @Test func `Warnings and errors find their line under a table header with a comment`() throws {
        let config = try Config.parse("[gaps] # the spacing\ninner = -1\n")
        #expect(config.warnings.map(\.line) == [2])
        assertError("[scrolling]   # the strip\ncolumn-width = 1.5\n", path: "scrolling.column-width", line: 2, contains: "0.1 to 1")
        assertError("[gaps]\ninner = 4\n[ scrolling ] # ]\ncolumn-width = 1.5\n", path: "scrolling.column-width", line: 4, contains: "0.1 to 1")
    }

    @Test func `Config lines break on CRLF, LF and CR only`() {
        #expect(configLines("a\r\nb\nc\rd\u{0C}e\u{2028}f") == ["a", "b", "c", "d\u{0C}e\u{2028}f"])
        #expect(configLines("x\n\n") == ["x", "", ""])
        #expect(configLines("") == [""])
    }

    @Test func `Warnings format suggestions and errors retain their location`() {
        let fix = ConfigFix(replace: "old-key", with: "new-key")
        #expect(ConfigWarning(path: "gaps.inner", "use the new key", line: 2, fix: fix).description ==
                "line 2, gaps.inner: use the new key (suggestion: replace 'old-key' with 'new-key')")
        #expect(ConfigError(path: "gaps.inner", "expected an integer", line: 2).description ==
                "line 2, gaps.inner: expected an integer")
    }

    @Test func `Configs without warnings stay equal to their defaults`() throws {
        #expect(try Config.parse(Config.defaultTOML).warnings == [])
        #expect(try Config.parse(Config.defaultTOML) == Config.default)
    }

    @Test func `Top-level keys`() throws {
        let config = try Config.parse("""
        start-at-login = false
        workspaces = 3
        follow-space-order = true
        follow-app-activation = false
        float-windows-without-fullscreen = false
        """)
        #expect(!config.startAtLogin)
        #expect(config.workspaces == 3)
        #expect(config.followSpaceOrder)
        #expect(!config.followAppActivation.enabled)
        #expect(!config.floatWindowsWithoutFullscreen)
        assertError("workspaces = 0\n", path: "workspaces", line: 1, contains: "at least 1")
        assertError("default-layout = 'tiles'\n", path: "default-layout", line: 1, contains: "unknown key")
    }

    @Test func `Workspace layouts`() throws {
        let config = try Config.parse("""
        default-tiling = false
        [workspace.2]
        tiling = true
        [workspace.3]
        fullscreen-width = 0.8
        """)
        #expect(!config.settings(forWorkspace: 1).tiling)
        #expect(config.settings(forWorkspace: 2).tiling)
        let three = config.settings(forWorkspace: 3)
        #expect(!three.tiling, "omitted keys inherit the top-level settings")
        #expect(three.fullscreenWidth == 0.8)
        #expect(config.settings(forWorkspace: nil) == WorkspaceSettings(tiling: false),
                "an unnumbered workspace gets the top-level settings")
        assertError("[workspace.0]\ntiling = true\n", path: "workspace.0", line: 1, contains: "positive workspace number")
        assertError("[workspace.2]\nlayout = 'fixed'\n", path: "workspace.2.layout", line: 2, contains: "unknown key")
    }

    @Test func `Workspace settings per display`() throws {
        let config = try Config.parse("""
        [workspace.2]
        fullscreen-width = 0.7
        [workspace.2.display.built-in]
        fullscreen-width = 0.9
        [workspace.2.display.main]
        lone-window-width = 0.6
        [workspace.2.display.'Built-in Retina']
        tiling = false
        [workspace.3.display.secondary]
        tiling = false
        """)
        let ultrawide = Monitor(name: "DELL U3824DW", isMain: true, count: 2)
        let laptop = Monitor(name: "Built-in Retina Display", isMain: false, count: 2)
        let otherLaptop = Monitor(name: "Built-in Liquid Retina XDR Display", isMain: false, count: 2)
        #expect(config.settings(forWorkspace: 2).fullscreenWidth == 0.7, "without a display, the workspace's own")
        let main = config.settings(forWorkspace: 2, on: ultrawide)
        #expect((main.fullscreenWidth, main.loneWindowWidth) == (0.7, 0.6), "omitted keys come from the workspace")
        #expect(config.settings(forWorkspace: 2, on: otherLaptop).fullscreenWidth == 0.9)
        #expect(!config.settings(forWorkspace: 2, on: laptop).tiling, "the longest name wins")
        #expect(config.settings(forWorkspace: 2, on: laptop).fullscreenWidth == 0.7, "and inherits from the workspace, not other displays")
        #expect(!config.settings(forWorkspace: 3, on: laptop).tiling)
        #expect(config.settings(forWorkspace: 3, on: ultrawide).tiling)
        #expect(config.settings(forWorkspace: 1, on: laptop) == config.settings(forWorkspace: 1))
        let ties = try Config.parse("[workspace.1.display.main]\ntiling = false\n[workspace.1.display.secondary]\ntiling = true\n")
        #expect(!ties.settings(forWorkspace: 1, on: Monitor(name: "x", isMain: true, count: 1)).tiling)
        assertError("[workspace.2.display.main]\ngaps.inner = 2\n", path: "workspace.2.display.main.gaps", line: 2, contains: "unknown key")
        assertError("[workspace.2.display.main.display.dell]\ntiling = true\n", path: "workspace.2.display.main.display",
                    line: 1, contains: "unknown key")
        assertError("[workspace.2.display.'']\ntiling = true\n", path: "workspace.2.display", line: 1, contains: "can't be empty")
    }

    @Test func `Fullscreen width`() throws {
        #expect(try Config.parse("").fullscreenWidth(forWorkspace: 1) == 1)
        #expect(try Config.parse("fullscreen-width = 1\n").fullscreenWidth == 1, "an integer 1 is a number too")
        let config = try Config.parse("""
        fullscreen-width = 0.8
        [display.dell]
        fullscreen-width = 0.55
        [display.main]
        gaps.inner = 2
        [workspace.2]
        fullscreen-width = 0.7
        [workspace.2.display.built-in]
        fullscreen-width = 0.9
        [workspace.3]
        tiling = true
        [workspace.3.display.dell]
        fullscreen-width = 0.6
        """)
        let dell = Monitor(name: "DELL U3421WE", isMain: true, count: 2)
        let laptop = Monitor(name: "Built-in Retina Display", isMain: false, count: 2)
        #expect(config.fullscreenWidth(forWorkspace: 1) == 0.8, "the top-level value")
        #expect(config.fullscreenWidth(forWorkspace: 1, on: laptop) == 0.8)
        #expect(config.fullscreenWidth(forWorkspace: 1, on: dell) == 0.55, "a display table overrides it; one without the key does not")
        #expect(config.fullscreenWidth(forWorkspace: 2, on: dell) == 0.7, "a workspace table overrides the display's")
        #expect(config.fullscreenWidth(forWorkspace: 2, on: laptop) == 0.9, "and its own display table that")
        #expect(config.fullscreenWidth(forWorkspace: 3, on: laptop) == 0.8, "a workspace table without the key inherits")
        #expect(config.fullscreenWidth(forWorkspace: 3, on: dell) == 0.6)
        #expect(config.fullscreenWidth(forWorkspace: nil, on: dell) == 0.55)
        assertError("fullscreen-width = 0.0\n", path: "fullscreen-width", line: 1, contains: "0.1 to 1")
        assertError("fullscreen-width = 1.5\n", path: "fullscreen-width", line: 1, contains: "0.1 to 1")
        assertError("[display.main]\nfullscreen-width = 2.0\n", path: "display.main.fullscreen-width", line: 2, contains: "0.1 to 1")
        assertError("[workspace.2]\nfullscreen-width = 0.05\n", path: "workspace.2.fullscreen-width", line: 2, contains: "0.1 to 1")
        assertError("[workspace.2.display.main]\nfullscreen-width = 0.0\n", path: "workspace.2.display.main.fullscreen-width",
                    line: 2, contains: "0.1 to 1")
    }

    @Test func `Lone window width cascades independently`() throws {
        #expect(try Config.parse("").loneWindowWidth == nil)
        #expect(try Config.parse("").loneWindowWidth(forWorkspace: 1) == 1)
        #expect(Config.default.loneWindowWidth == nil)
        #expect(try Config.parse("lone-window-width = 1").loneWindowWidth == 1)
        #expect(try Config.parse("lone-window-width = 0.1").loneWindowWidth == 0.1)
        let config = try Config.parse("""
        fullscreen-width = 1.0
        lone-window-width = 0.75
        [display.main]
        lone-window-width = 0.6
        [display.dell]
        lone-window-width = 0.55
        [display.'dell u']
        gaps.inner = 2
        [workspace.2]
        lone-window-width = 0.7
        [workspace.2.display.built-in]
        lone-window-width = 0.9
        [workspace.3]
        fullscreen-width = 0.4
        [workspace.3.display.dell]
        lone-window-width = 0.8
        [workspace.4]
        lone-window-width = 0.65
        [workspace.4.display.main]
        fullscreen-width = 0.4
        """)
        let dell = Monitor(name: "DELL U3421WE", isMain: true, count: 2)
        let laptop = Monitor(name: "Built-in Retina Display", isMain: false, count: 2)
        #expect(config.loneWindowWidth(forWorkspace: 1) == 0.75)
        #expect(config.loneWindowWidth(forWorkspace: 1, on: laptop) == 0.75)
        #expect(config.loneWindowWidth(forWorkspace: nil, on: dell) == 0.55)
        #expect(config.loneWindowWidth(forWorkspace: 2, on: dell) == 0.7)
        #expect(config.loneWindowWidth(forWorkspace: 2, on: laptop) == 0.9)
        #expect(config.loneWindowWidth(forWorkspace: 3, on: laptop) == 0.75, "exhaust the lone-window cascade before falling back")
        #expect(config.loneWindowWidth(forWorkspace: 3, on: dell) == 0.8)
        #expect(config.loneWindowWidth(forWorkspace: 4, on: dell) == 0.65, "an omitted display key inherits its workspace's width")
        #expect(config.fullscreenWidth(forWorkspace: 1, on: dell) == 1)
    }

    @Test func `Lone window width falls back to resolved fullscreen width`() throws {
        let config = try Config.parse("""
        fullscreen-width = 0.8
        [display.main]
        fullscreen-width = 0.6
        [workspace.2]
        fullscreen-width = 0.7
        [workspace.2.display.main]
        fullscreen-width = 0.9
        """)
        let monitor = Monitor(name: "Built-in", isMain: true, count: 1)
        #expect(config.loneWindowWidth(forWorkspace: 1) == 0.8)
        #expect(config.loneWindowWidth(forWorkspace: nil, on: monitor) == 0.6)
        #expect(config.loneWindowWidth(forWorkspace: 2) == 0.7)
        #expect(config.loneWindowWidth(forWorkspace: 2, on: monitor) == 0.9)
    }

    @Test func `Lone window width validates every level`() {
        for prefix in ["", "display.main.", "workspace.2.", "workspace.2.display.main."] {
            let table = prefix.isEmpty ? "" : "[\(prefix.dropLast())]\n"
            for value in ["0.0", "1.5"] {
                assertError("\(table)lone-window-width = \(value)\n", path: "\(prefix)lone-window-width",
                            line: prefix.isEmpty ? 1 : 2, contains: "0.1 to 1")
            }
        }
    }

    @Test func `Unknown top-level key fails`() {
        assertError("workspaces = 3\ngap = 8\n", path: "gap", line: 2, contains: "unknown key")
        assertError("config-version = 1\n", path: "config-version", line: 1, contains: "unknown key")
        assertError("auto-reload-config = true\n", path: "auto-reload-config", line: 1, contains: "unknown key")
    }

    @Test func `Unknown key in table fails`() {
        assertError("[gaps]\ninner = 8\n\n[borders]\nwidht = 4\n", path: "borders.widht", line: 5, contains: "unknown key")
        assertError("[gaps]\nouter = { top = 8, tpo = 8 }\n", path: "gaps.outer.tpo", line: 2, contains: "unknown key")
        assertError("[[rules]]\napp-idd = 'x'\nrun = 'y'\n", path: "rules[0].app-idd", line: 2, contains: "unknown key")
        assertError("[switching]\nfollow-app-activation = true\n", path: "switching", line: 1, contains: "unknown key")
        assertError("[layout]\ndefault = 'tiles'\n", path: "layout", line: 1, contains: "unknown key")
        assertError("[borders]\nonly-apps = []\n", path: "borders.only-apps", line: 2, contains: "unknown key")
    }

    @Test func `Bad type fails`() {
        assertError("[gaps]\ninner = 'wide'\n", path: "gaps.inner", line: 2, contains: "expected an integer")
        assertError("workspaces = true\n", path: "workspaces", line: 1, contains: "expected an integer")
        assertError("gaps = 8\n", path: "gaps", line: 1, contains: "expected a table")
        assertError("block-native-fullscreen = 'yes'\n", path: "block-native-fullscreen", line: 1, contains: "true or false")
    }

    @Test func `Negative sizes load as written, with warnings`() throws {
        // Older danky loaded these values as written, so they still do; the warning suggests 0.
        let inner = try Config.parse("[gaps]\ninner = -4\n")
        #expect(inner.gaps.inner == Inner(-4))
        #expect(inner.warnings == [ConfigWarning(path: "gaps.inner", "should be 0 or more; still read as -4", line: 2,
                                                  fix: ConfigFix(replace: "-4", with: "0"))])

        let innerTable = try Config.parse("[gaps]\ninner = { horizontal = 8, vertical = -1 }\n")
        #expect(innerTable.gaps.inner == Inner(horizontal: 8, vertical: -1))
        #expect(innerTable.warnings == [ConfigWarning(path: "gaps.inner.vertical", "should be 0 or more; still read as -1",
                                                       line: 2, fix: ConfigFix(replace: "-1", with: "0"))])

        let outer = try Config.parse("[gaps]\nouter = -8\n")
        #expect(outer.gaps.outer == Sides(-8))
        #expect(outer.warnings == [ConfigWarning(path: "gaps.outer", "should be 0 or more; still read as -8", line: 2,
                                                  fix: ConfigFix(replace: "-8", with: "0"))])

        let outerTable = try Config.parse("[gaps]\nouter = { top = 44, left = -8 }\n")
        #expect(outerTable.gaps.outer == Sides(top: 44, bottom: 8, left: -8, right: 8))
        #expect(outerTable.warnings == [ConfigWarning(path: "gaps.outer.left", "should be 0 or more; still read as -8",
                                                       line: 2, fix: ConfigFix(replace: "-8", with: "0"))])

        let display = try Config.parse("[display.main.gaps]\nouter = -8\n")
        let patch = display.displays[0].gaps
        #expect([patch.top, patch.bottom, patch.left, patch.right] == [-8, -8, -8, -8])
        #expect(display.warnings == [ConfigWarning(path: "display.main.gaps.outer", "should be 0 or more; still read as -8",
                                                   line: 2, fix: ConfigFix(replace: "-8", with: "0"))])


        for (value, number) in [("-2", -2.0), ("-2.0", -2.0), ("-2.5", -2.5)] {
            let config = try Config.parse("[borders]\nwidth = \(value)\n")
            let written = number == -2.5 ? "-2.5" : "-2"
            #expect(config.borders.width == number)
            #expect(config.warnings == [ConfigWarning(path: "borders.width", "should be 0 or more; still read as \(written)",
                                                       line: 2, fix: ConfigFix(replace: written, with: "0"))])
        }

        // Suggestions describe replacement values for a person; they are not executable source edits.
        for (value, replacement) in [("inf", "inf"), ("+inf", "inf"), ("-inf", "-inf"),
                                     ("nan", "nan"), ("+nan", "nan"), ("-nan", "-nan")] {
            let config = try Config.parse("[borders]\nwidth = \(value)\n")
            #expect(config.borders.width == 4)
            #expect(config.warnings == [ConfigWarning(
                path: "borders.width",
                "must be a finite number, 0 or more; using the default, 4",
                line: 2,
                fix: ConfigFix(replace: replacement, with: "4")
            )])
        }
    }

    @Test func accordion() throws {
        assertError("[accordion]\npadding = 12\n", path: "accordion", line: 1, contains: "unknown key")
    }

    @Test func scrolling() throws {
        #expect(Config().scrolling.columnWidth == 0.5)
        let thirds: [Double] = [0.33333, 0.5, 0.66667]
        #expect(Config().scrolling.presetColumnWidths == thirds, "niri's defaults")
        #expect(try Config.parse("[scrolling]\ncolumn-width = 0.6\n").scrolling.columnWidth == 0.6)
        let presets = try Config.parse("[scrolling]\npreset-column-widths = [0.75, 0.25, 1]\n").scrolling.presetColumnWidths
        #expect(presets == [0.25, 0.75, 1], "sorted, an integer read as a number")
        assertError("[scrolling]\ncolumn-width = 1.5\n", path: "scrolling.column-width", line: 2, contains: "0.1 to 1")
        assertError("[scrolling]\npreset-column-widths = []\n", path: "scrolling.preset-column-widths", line: 2, contains: "at least one")
        assertError("[scrolling]\npreset-column-widths = [0.5, 2]\n", path: "scrolling.preset-column-widths", line: 2, contains: "0.1 to 1")
        assertError("[scrolling]\npreset-column-widths = ['half']\n", path: "scrolling.preset-column-widths", line: 2, contains: "list of numbers")
        assertError("[master]\nsize = 0.6\n", path: "master", line: 1, contains: "unknown key")
    }

    @Test func `Syntax error has line`() {
        let error = #expect(throws: ConfigError.self) {
            try Config.parse("workspaces = 5\n[gaps\n")
        }
        if let error { #expect("\(error)".contains("Line 2"), "\(error)") }
    }

    @Test func colours() throws {
        #expect(try Color(hex: "#ff000080") == Color(red: 1, green: 0, blue: 0, alpha: 128 / 255))
        #expect(try Color(hex: "#00FF00") == Color(red: 0, green: 1, blue: 0))
        for bad in ["e1e3e4", "#e1e3", "#e1e3e4g", "#+1e3e4", "0xff0000", "0x80ff0000"] {
            #expect(throws: ConfigError.self, "\(bad)") { try Color(hex: bad) }
        }
        assertError("[borders]\nactive-color = 'red'\n", path: "borders.active-color", line: 2, contains: "'red' is not a colour")
    }

    @Test func borders() throws {
        #expect(Config().borders.order == .below)
        let borders = try Config.parse("""
        [borders]
        order = 'above'
        width = 2.5
        exclude-apps = ['com.apple.finder', 'com.apple.Terminal']
        """).borders
        #expect(borders.order == .above)
        #expect(borders.width == 2.5)
        #expect(borders.excludeApps == ["com.apple.finder", "com.apple.Terminal"])
        #expect(!borders.decorates(bundleID: "com.apple.finder"))
        #expect(borders.decorates(bundleID: "com.apple.TextEdit"))
        #expect(borders.decorates(bundleID: nil))

        assertError("[borders]\norder = 'over'\n", path: "borders.order", line: 2, contains: "'below', 'above'")
        assertError("[borders]\nexclude-apps = 'com.apple.finder'\n", path: "borders.exclude-apps", line: 2, contains: "list of strings")
    }

    @Test func `Follow app activation`() throws {
        #expect(try Config.parse("").followAppActivation == FollowAppActivation())
        #expect(try Config.parse("follow-app-activation = true\n").followAppActivation.enabled)
        #expect(try !Config.parse("follow-app-activation = false\n").followAppActivation.enabled)

        let table = try Config.parse("""
        [follow-app-activation]
        enabled = false
        exclude-apps = ['com.synology.SynologyDrive', 'com.apple.TextEdit']
        """).followAppActivation
        #expect(!table.enabled)
        #expect(table.excludeApps == ["com.synology.SynologyDrive", "com.apple.TextEdit"])

        let excludeOnly = try Config.parse("""
        [follow-app-activation]
        exclude-apps = ['com.synology.SynologyDrive']
        """).followAppActivation
        #expect(excludeOnly.enabled)
        #expect(!excludeOnly.follows(bundleID: "com.synology.SynologyDrive"))
        #expect(excludeOnly.follows(bundleID: "com.apple.TextEdit"))
        #expect(excludeOnly.follows(bundleID: nil))

        assertError("follow-app-activation = 'yes'\n", path: "follow-app-activation", line: 1, contains: "true or false")
        assertError("[follow-app-activation]\nexclude-apps = 'com.apple.finder'\n", path: "follow-app-activation.exclude-apps", line: 2, contains: "list of strings")
        assertError("[follow-app-activation]\npaused = true\n", path: "follow-app-activation.paused", line: 2, contains: "unknown key")
    }

    @Test func `Binding values`() throws {
        let config = try Config.parse("""
        [bindings]
        alt-a = 'workspace 1'
        alt-b = ['layout floating', 'balance-sizes']
        ctrl-h = { command = 'focus left --wrap-around', exclude-apps = ['com.github.wez.wezterm', 'com.mitchellh.ghostty'] }
        ctrl-j = { command = ['focus down', 'balance-sizes'] }
        ctrl-k = { command = 'focus up' }
        """)
        let main = config.bindings.bindings
        #expect(main[KeyCombo(modifiers: .alt, key: "a")] == KeyBinding(["workspace 1"]))
        #expect(main[KeyCombo(modifiers: .alt, key: "b")] == KeyBinding(["layout floating", "balance-sizes"]))
        #expect(main[KeyCombo(modifiers: .ctrl, key: "h")] == KeyBinding(["focus left --wrap-around"],
                                                                         excludeApps: ["com.github.wez.wezterm", "com.mitchellh.ghostty"]))
        #expect(main[KeyCombo(modifiers: .ctrl, key: "j")] == KeyBinding(["focus down", "balance-sizes"]))
        #expect(main[KeyCombo(modifiers: .ctrl, key: "k")] == KeyBinding(["focus up"]))
        assertError("[mode.main]\nalt-a = 'workspace 1'\n", path: "mode", line: 1, contains: "put the keys of [mode.main] under [bindings]")
    }

    @Test func `Binding exclusions`() {
        let binding = KeyBinding(["focus left"], excludeApps: ["com.example.Terminal"])
        #expect(!binding.applies(to: "com.example.Terminal"))
        #expect(binding.applies(to: "com.apple.TextEdit"))
        #expect(binding.applies(to: nil))
        #expect(KeyBinding(["focus left"]).applies(to: "com.example.Terminal"))
    }

    @Test func `Bad binding values fail`() {
        assertError("[bindings]\nalt-a = ''\n", path: "bindings.alt-a", line: 2, contains: "can't be empty")
        assertError("[bindings]\nalt-a = []\n", path: "bindings.alt-a", line: 2, contains: "can't be empty")
        assertError("[bindings]\nalt-a = 3\n", path: "bindings.alt-a", line: 2, contains: "command string")
        assertError("[bindings]\nalt-a = ['x', 3]\n", path: "bindings.alt-a", line: 2, contains: "command string")
        assertError("[bindings]\nalt-a = { exclude-apps = ['com.example.App'] }\n", path: "bindings.alt-a.command", line: 2, contains: "missing, a binding table needs 'command'")
        assertError("[bindings]\nalt-a = { command = 'x', ignored = true }\n", path: "bindings.alt-a.ignored", line: 2, contains: "unknown key")
        assertError("[bindings]\nalt-a = { command = 'x', exclude-apps = 'com.example.App' }\n", path: "bindings.alt-a.exclude-apps", line: 2, contains: "list of strings")
        assertError("[bindings]\nalt-a = { command = '' }\n", path: "bindings.alt-a.command", line: 2, contains: "can't be empty")
        assertError("[bindings]\nalt-super-a = 'x'\n", path: "bindings.alt-super-a", line: 2, contains: "'alt-super-a'")
        assertError("[bindings]\nalt-shift-a = 'x'\nshift-alt-a = 'y'\n", path: "bindings.shift-alt-a", line: 3, contains: "bound twice")
        assertError("[bindings]\nhyper-a = 'x'\nctrl-alt-cmd-shift-a = 'y'\n", path: "bindings.ctrl-alt-cmd-shift-a", line: 3, contains: "bound twice")
        assertError("[bindings.binding]\nalt-a = 'x'\n", path: "bindings.binding", line: 1, contains: "'binding'")
    }

    @Test func `Window rule round-trips`() throws {
        let config = try Config.parse("""
        [[rules]]
        app-id = 'com.apple.finder'
        app-name = 'find'
        title = '^Copy'
        kind = 'dialog'
        run = ['layout floating', 'move-window-to-workspace 2']

        [[rules]]
        run = 'layout tiling'
        """)
        var expected = WindowRule()
        expected.match.appId = "com.apple.finder"
        expected.match.appName = "find"
        expected.match.title = "^Copy"
        expected.match.kind = .dialog
        expected.run = ["layout floating", "move-window-to-workspace 2"]
        var second = WindowRule()
        second.run = ["layout tiling"]
        #expect(config.rules == [expected, second])

        #expect(expected.match.matches(appId: "com.apple.finder", appName: "Finder", title: "Copy 3 items", kind: .dialog))
        #expect(!expected.match.matches(appId: "com.apple.finder", appName: "Finder", title: "Copy 3 items", kind: .normal))
        #expect(!expected.match.matches(appId: "com.apple.finder", appName: "Finder", title: "Desktop", kind: .dialog))
        #expect(!expected.match.matches(appId: "com.apple.Safari", appName: "Finder", title: "Copy", kind: .dialog))
        #expect(second.match.matches(appId: nil, appName: nil, title: "", kind: .normal), "a rule with no conditions matches everything")
    }

    @Test func `Window rule matches the bundle ID by regex`() throws {
        let config = try Config.parse("""
        [[rules]]
        app-id-regex = '^co\\.ensili\\.'
        run = 'layout floating'

        [[rules]]
        app-id = 'co.ensili.Scrivener'
        app-id-regex = 'scrivener$'
        run = 'layout floating'
        """)
        var expected = WindowRule()
        expected.match.appIdRegex = "^co\\.ensili\\."
        expected.run = ["layout floating"]
        #expect(config.rules.first == expected)

        let prefix = config.rules[0], both = config.rules[1]
        #expect(prefix.match.matches(appId: "co.ensili.Scrivener", appName: "Scrivener", title: "", kind: .normal))
        #expect(prefix.match.matches(appId: "CO.Ensili.Other", appName: nil, title: "", kind: .normal), "case-insensitive")
        #expect(!prefix.match.matches(appId: "uk.co.ensili.x", appName: nil, title: "", kind: .normal), "anchored by the pattern")
        #expect(!prefix.match.matches(appId: nil, appName: "Scrivener", title: "", kind: .normal), "no bundle ID never matches")
        #expect(both.match.matches(appId: "co.ensili.Scrivener", appName: nil, title: "", kind: .normal))
        #expect(!both.match.matches(appId: "co.ensili.scrivener", appName: nil, title: "", kind: .normal), "app-id stays exact")
    }

    @Test func `Bad window rules fail`() {
        assertError("[[rules]]\napp-id = 'x'\n", path: "rules[0].run", line: 1, contains: "every rule needs 'run'")
        assertError("[[rules]]\ntitle = '('\nrun = 'x'\n", path: "rules[0].title", line: 2, contains: "not a valid regex")
        assertError("[[rules]]\napp-id-regex = '['\nrun = 'x'\n", path: "rules[0].app-id-regex", line: 2, contains: "not a valid regex")
        assertError("[[rules]]\nkind = 'popup'\nrun = 'x'\n", path: "rules[0].kind", line: 2, contains: "'normal', 'dialog', 'sheet', 'panel'")
        assertError("[[rules]]\nif.app-id = 'x'\nrun = 'y'\n", path: "rules[0].if", line: 2, contains: "unknown key")
    }

    @Test func hooks() throws {
        #expect(Config.default.hooks == Hooks())
        let hooks = try Config.parse("""
        [hooks]
        startup = 'exec-and-forget brew services restart sketchybar'
        workspace-changing = 'exec-and-forget sketchybar --trigger workspace_changing'
        workspace-changed = ['exec-and-forget sketchybar --trigger workspace_change']
        focus-changed = []
        display-changed = 'layout accordion'
        """).hooks
        #expect(hooks.startup == ["exec-and-forget brew services restart sketchybar"])
        #expect(hooks.workspaceChanging == ["exec-and-forget sketchybar --trigger workspace_changing"])
        #expect(hooks.workspaceChanged == ["exec-and-forget sketchybar --trigger workspace_change"])
        #expect(hooks.focusChanged == [])
        #expect(hooks.displayChanged == ["layout accordion"])
        assertError("[hooks]\nfocus-changed = [1]\n", path: "hooks.focus-changed", line: 2, contains: "command string")
        assertError("[hooks]\nstartup = ['']\n", path: "hooks.startup", line: 2, contains: "can't be empty")
        assertError("[hooks]\non-startup = 'x'\n", path: "hooks.on-startup", line: 2, contains: "unknown key")
        assertError("after-startup-command = ['x']\n", path: "after-startup-command", line: 1, contains: "unknown key")
    }

    @Test func `Focus follows mouse`() throws {
        let defaults = Config.default.focusFollowsMouse
        #expect(defaults == FocusFollowsMouse())
        #expect(!defaults.enabled)
        #expect(defaults.delayMs == 100)
        let ffm = try Config.parse("""
        [focus-follows-mouse]
        enabled = true
        delay-ms = 0
        """).focusFollowsMouse
        #expect(ffm.enabled)
        #expect(ffm.delayMs == 0)
        assertError("[focus-follows-mouse]\ndelay-ms = -1\n", path: "focus-follows-mouse.delay-ms", line: 2, contains: "0 or more")
        assertError("[focus-follows-mouse]\naccordion = true\n", path: "focus-follows-mouse.accordion", line: 2, contains: "unknown key")
    }

    @Test func `Trackpad swipe`() throws {
        let defaults = Config.default.swipe
        #expect(defaults == Swipe())
        #expect(!defaults.enabled)
        #expect(defaults.spaceSwitch == .instant)
        #expect(!defaults.vertical)
        let swipe = try Config.parse("""
        [swipe]
        enabled = true
        space-switch = 'native'
        vertical = true
        """).swipe
        #expect(swipe.enabled)
        #expect(swipe.spaceSwitch == .native)
        #expect(swipe.vertical)
        assertError("[swipe]\nspace-switch = 'slide'\n", path: "swipe.space-switch", line: 2, contains: "'instant', 'native'")
        assertError("[swipe]\nfingers = 3\n", path: "swipe.fingers", line: 2, contains: "unknown key")
    }

    @Test func `Animations and drag`() throws {
        #expect(Config.default.animations == Animations())
        #expect(Config.default.drag == Drag())
        let config = try Config.parse("""
        [animations]
        enabled = false
        duration-ms = 300
        resize = 'glide'
        [drag]
        placeholders = false
        """)
        #expect(!config.animations.enabled)
        #expect(config.animations.durationMs == 300)
        #expect(config.animations.resize == .glide)
        #expect(Animations().resize == .instant, "sizes jump by default, only positions glide")
        #expect(!config.drag.placeholders)
        assertError("[drag]\nsplit-trigger = 'alt'\n", path: "drag.split-trigger", line: 2, contains: "unknown key")
        assertError("[animations]\nresize = 'slow'\n", path: "animations.resize", line: 2, contains: "'instant', 'glide'")
        assertError("[animations]\nduration-ms = -1\n", path: "animations.duration-ms", line: 2, contains: "0 to 1000")
        assertError("[drag]\nghost = true\n", path: "drag.ghost", line: 2, contains: "unknown key")
    }

    @Test func `Modifier sides`() throws {
        #expect(Config.default.modifiers == ModifierSides())
        let config = try Config.parse("[modifiers]\nalt = 'left'\nshift = 'right'\n")
        #expect(config.modifiers.alt == .left)
        #expect(config.modifiers.ctrl == .both)
        #expect(config.modifiers.shift == .right)
        assertError("[modifiers]\nalt = 'up'\n", path: "modifiers.alt", line: 2, contains: "'both', 'left', 'right'")
        assertError("[modifiers]\nfn = 'left'\n", path: "modifiers.fn", line: 2, contains: "unknown key")
    }

    @Test func `Load from missing file fails`() {
        let error = #expect(throws: ConfigError.self) {
            try Config.load(from: URL(fileURLWithPath: "/nonexistent/danky.toml"))
        }
        if let error { #expect("\(error)".contains("/nonexistent/danky.toml")) }
    }
}
