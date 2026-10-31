import Foundation
import PackagePlugin

// SwiftPM counterpart of install.sh: copies skills/<name>/ folders into the
// consuming package. Keep the --tool table in sync with install.sh.
@main
struct InstallIOSSkills: CommandPlugin {
    private static let destinations: [String: String] = [
        "claude": ".claude/skills",
        "cursor": ".cursor/skills",
        "copilot": ".github/skills",
        "gemini": ".gemini/skills",
    ]

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var extractor = ArgumentExtractor(arguments)
        if extractor.extractFlag(named: "help") > 0 {
            print(Self.usage)
            return
        }
        let tool = extractor.extractOption(named: "tool").last ?? "claude"
        let onlySkill = extractor.extractOption(named: "skill").last
        if !extractor.remainingArguments.isEmpty {
            throw PluginError("Unknown arguments: \(extractor.remainingArguments.joined(separator: " "))\n\n\(Self.usage)")
        }
        guard let relativeDestination = Self.destinations[tool] else {
            throw PluginError("Unknown --tool '\(tool)'. Expected one of: \(Self.destinations.keys.sorted().joined(separator: ", ")). For Codex, use its plugin marketplace instead.")
        }

        let fileManager = FileManager.default
        guard let source = Self.skillsDirectory(in: context.package) else {
            throw PluginError("Couldn't find the ios-claude-skills package's skills/ folder. Is ios-claude-skills a dependency of this package?")
        }
        let destination = URL(fileURLWithPath: context.package.directory.string)
            .appendingPathComponent(relativeDestination, isDirectory: true)

        var names = try fileManager.contentsOfDirectory(atPath: source.path)
            .filter { fileManager.fileExists(atPath: source.appendingPathComponent($0).appendingPathComponent("SKILL.md").path) }
            .sorted()
        if let onlySkill {
            guard names.contains(onlySkill) else {
                throw PluginError("No skill named '\(onlySkill)' found under skills/.")
            }
            names = [onlySkill]
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in names {
            let target = destination.appendingPathComponent(name, isDirectory: true)
            // Replace, don't merge, so files removed from a skill upstream disappear too.
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: source.appendingPathComponent(name, isDirectory: true), to: target)
        }

        print("Installed \(names.count == 1 ? names[0] : "\(names.count) skills") -> \(relativeDestination)")
        print("Restart \(tool) (or start a new session) so it picks up the new skills.")
    }

    /// Finds skills/ in this package or any dependency named ios-claude-skills.
    private static func skillsDirectory(in package: Package) -> URL? {
        var queue = [package]
        var seen = Set<String>()
        while !queue.isEmpty {
            let candidate = queue.removeFirst()
            guard seen.insert(candidate.id).inserted else { continue }
            if candidate.displayName == "ios-claude-skills" {
                let skills = URL(fileURLWithPath: candidate.directory.string).appendingPathComponent("skills", isDirectory: true)
                if FileManager.default.fileExists(atPath: skills.path) {
                    return skills
                }
            }
            queue.append(contentsOf: candidate.dependencies.map(\.package))
        }
        return nil
    }

    private static let usage = """
    Usage:
      swift package --allow-writing-to-package-directory install-ios-skills [options]

    Options:
      --tool <claude|cursor|copilot|gemini>   Target tool (default: claude)
      --skill <name>                          Install only this one skill (default: all)
      --help                                  Show this help
    """
}

struct PluginError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
