// swift-tools-version:5.9
// Ships the skills through SwiftPM as a command plugin. There is no library to
// link; the plugin only copies skills/ into the consuming package.
import PackageDescription

let package = Package(
    name: "ios-claude-skills",
    products: [
        .plugin(name: "InstallIOSSkills", targets: ["InstallIOSSkills"]),
    ],
    targets: [
        .plugin(
            name: "InstallIOSSkills",
            capability: .command(
                intent: .custom(
                    verb: "install-ios-skills",
                    description: "Copy the ios-claude-skills skills into this package for Claude Code, Cursor, Copilot or Gemini CLI."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Copies skill folders into .claude/skills (or the chosen tool's skills folder)."),
                ]
            ),
            path: "Plugins/InstallIOSSkills"
        ),
    ]
)
