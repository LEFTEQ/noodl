import Foundation

enum MarkdownParser {

    static func parse(url: URL) -> TodoProject? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let lines = contents.components(separatedBy: "\n")
        var name = url.deletingPathExtension().lastPathComponent
        var items: [TodoItem] = []

        for line in lines {
            // Extract project name from h1
            if line.hasPrefix("# ") {
                name = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            // Skip footer lines
            if line.hasPrefix("**Open:") { continue }

            // Parse todo line
            let todoPattern = /^- \[([ x])\] (.+?)(?:\s+(!(?:high|low)))?\s*$/
            if let match = try? todoPattern.firstMatch(in: line) {
                let isDone = match.1 == "x"
                let title = String(match.2).trimmingCharacters(in: .whitespaces)
                let priorityRaw = match.3.map(String.init)
                let priority = priorityRaw.flatMap { TodoItem.Priority(rawValue: $0) }
                items.append(TodoItem(title: title, isDone: isDone, priority: priority))
            }
        }

        return TodoProject(name: name, filePath: url, items: items)
    }

    static func serialize(_ project: TodoProject) -> String {
        var lines: [String] = []
        lines.append("# \(project.name)")
        lines.append("")

        // Open items first, then done items
        let openItems = project.items.filter { !$0.isDone }
        let doneItems = project.items.filter { $0.isDone }

        for item in openItems + doneItems {
            let check = item.isDone ? "x" : " "
            var line = "- [\(check)] \(item.title)"
            if let priority = item.priority {
                line += " \(priority.rawValue)"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append("**Open: \(project.openCount) | Done: \(project.doneCount)**")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    static func write(_ project: TodoProject) throws {
        let content = serialize(project)
        try content.write(to: project.filePath, atomically: true, encoding: .utf8)
    }

    static func createEmpty(name: String, at url: URL) throws {
        let project = TodoProject(name: name, filePath: url, items: [])
        try write(project)
    }

    // MARK: - Snippets

    static func parseSnippets(url: URL) -> [Snippet] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let lines = contents.components(separatedBy: "\n")
        var snippets: [Snippet] = []
        var currentTitle: String?
        var currentLines: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                // Save previous snippet
                if let title = currentTitle {
                    let content = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        snippets.append(Snippet(title: title, content: content))
                    }
                }
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else if line.hasPrefix("# ") {
                // Skip h1 header
                continue
            } else if currentTitle != nil {
                currentLines.append(line)
            }
        }

        // Save last snippet
        if let title = currentTitle {
            let content = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                snippets.append(Snippet(title: title, content: content))
            }
        }

        return snippets
    }

    // MARK: - Commands

    static func parseCommands(url: URL) -> [QuickCommand] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let lines = contents.components(separatedBy: "\n")
        var commands: [QuickCommand] = []
        var currentTitle: String?
        var currentKind: QuickCommand.Kind?
        var currentLines: [String] = []
        var inCodeBlock = false

        for line in lines {
            if line.hasPrefix("## ") && !inCodeBlock {
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if let title = currentTitle {
                if line.hasPrefix("```shell") {
                    inCodeBlock = true
                    currentKind = .shell
                    currentLines = []
                } else if line.hasPrefix("```ai") {
                    inCodeBlock = true
                    currentKind = .ai
                    currentLines = []
                } else if line.hasPrefix("```") && inCodeBlock {
                    // End of code block
                    inCodeBlock = false
                    let command = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !command.isEmpty, let kind = currentKind {
                        commands.append(QuickCommand(title: title, command: command, kind: kind))
                    }
                    currentTitle = nil
                    currentKind = nil
                } else if inCodeBlock {
                    currentLines.append(line)
                }
            }
        }

        return commands
    }

    static func writeSnippets(_ snippets: [Snippet], to url: URL) throws {
        var lines: [String] = ["# Snippets", ""]
        for snippet in snippets {
            lines.append("## \(snippet.title)")
            lines.append(snippet.content)
            lines.append("")
        }
        let content = lines.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func writeCommands(_ commands: [QuickCommand], to url: URL) throws {
        var lines: [String] = ["# Commands", ""]
        for command in commands {
            lines.append("## \(command.title)")
            lines.append("```\(command.kind.rawValue)")
            lines.append(command.command)
            lines.append("```")
            lines.append("")
        }
        let content = lines.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
