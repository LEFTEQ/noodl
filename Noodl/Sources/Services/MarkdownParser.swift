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
}
