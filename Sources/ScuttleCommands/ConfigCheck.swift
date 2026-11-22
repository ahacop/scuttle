import ScuttleConfig

/// A problem `scuttle doctor` found in a config that still parsed.
public struct ConfigFinding: Equatable, CustomStringConvertible {
    public enum Level: String { case error, warning }
    public let level: Level
    public let message: String

    public var description: String { "\(level.rawValue): \(message)" }
}

/// Checks a parsed config beyond what parsing guarantees: parser warnings, every binding and rule command in the
/// vocabulary, some bindings, and no `[workspace.N]` table past the last workspace.
public func checkConfig(_ config: Config) -> [ConfigFinding] {
    var findings = config.warnings.map { ConfigFinding(level: .warning, message: $0.description) }
    func check(_ commands: [String], at place: String) {
        for text in commands {
            do {
                _ = try Command.parse(text)
            } catch {
                findings.append(.init(level: .error, message: "\(place): \(error)"))
            }
        }
    }
    if config.bindings.bindings.isEmpty {
        findings.append(.init(level: .warning, message: "no [bindings]: no key bindings are active"))
    }
    // Harmless, so parsing accepts it; but a typo or a lowered `workspaces` leaves settings that never apply.
    for number in config.workspaceLayouts.keys.sorted() where number > config.workspaces {
        findings.append(.init(level: .warning, message: "workspace.\(number): past the last workspace (\(config.workspaces)), so it does nothing"))
    }
    for (combo, binding) in config.bindings.bindings.sorted(by: { $0.key.description < $1.key.description }) {
        check(binding.commands, at: "bindings.\(combo)")
    }
    for (i, rule) in config.rules.enumerated() {
        check(rule.run, at: "rules[\(i)].run")
    }
    check(config.hooks.startup, at: "hooks.startup")
    check(config.hooks.workspaceChanging, at: "hooks.workspace-changing")
    check(config.hooks.workspaceChanged, at: "hooks.workspace-changed")
    check(config.hooks.focusChanged, at: "hooks.focus-changed")
    check(config.hooks.displayChanged, at: "hooks.display-changed")
    return findings
}
