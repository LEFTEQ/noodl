import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class TodoStore {
    var projects: [TodoProject] = []
    var snippets: [Snippet] = []
    var commands: [QuickCommand] = []
    var directoryURL: URL
    var lastExpandedProject: TodoProject?

    private var watcher: FileWatcher?

    var totalOpen: Int { projects.reduce(0) { $0 + $1.openCount } }
    var totalDone: Int { projects.reduce(0) { $0 + $1.doneCount } }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.directoryURL = home.appendingPathComponent("Documents/Work/personal/noodl")
        self.projects = []
        reload()
        startWatching()
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            projects = []
            snippets = []
            commands = []
            return
        }

        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil))
            ?? []

        let mdFiles = urls.filter { $0.pathExtension == "md" }

        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        snippets = MarkdownParser.parseSnippets(url: snippetsURL)

        let commandsURL = directoryURL.appendingPathComponent("_commands.md")
        commands = MarkdownParser.parseCommands(url: commandsURL)

        let parsed = mdFiles
            .filter { !$0.lastPathComponent.hasPrefix("_") }
            .compactMap { MarkdownParser.parse(url: $0) }
            .sorted { lhs, rhs in
                if lhs.name.lowercased() == "inbox" { return false }
                if rhs.name.lowercased() == "inbox" { return true }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }

        projects = parsed
    }

    // MARK: - Todos

    func toggle(_ item: TodoItem, in project: TodoProject) {
        guard let pi = projects.firstIndex(where: { $0.id == project.id }),
              let ii = projects[pi].items.firstIndex(where: { $0.id == item.id }) else { return }
        projects[pi].items[ii].isDone.toggle()
        writeBack(projects[pi])
    }

    func add(title: String, priority: TodoItem.Priority?, to project: TodoProject) {
        guard let pi = projects.firstIndex(where: { $0.id == project.id }) else { return }
        let item = TodoItem(title: title, priority: priority)
        projects[pi].items.append(item)
        writeBack(projects[pi])
    }

    func remove(_ item: TodoItem, from project: TodoProject) {
        guard let pi = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[pi].items.removeAll { $0.id == item.id }
        writeBack(projects[pi])
    }

    func addProject(name: String) {
        let fileName = name.lowercased().replacingOccurrences(of: " ", with: "-") + ".md"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? MarkdownParser.createEmpty(name: name, at: fileURL)
        reload()
    }

    @discardableResult
    func pasteAsTodo() -> String? {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? text.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: TodoProject
        if let expanded = lastExpandedProject, projects.contains(where: { $0.id == expanded.id }) {
            target = expanded
        } else {
            let inboxURL = directoryURL.appendingPathComponent("Inbox.md")
            if !projects.contains(where: { $0.name == "Inbox" }) {
                try? MarkdownParser.createEmpty(name: "Inbox", at: inboxURL)
                reload()
            }
            guard let inbox = projects.first(where: { $0.name == "Inbox" }) else { return nil }
            target = inbox
        }

        add(title: title, priority: nil, to: target)
        return title
    }

    // MARK: - Snippets

    func addSnippet(title: String, content: String) {
        snippets.append(Snippet(title: title, content: content))
        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        try? MarkdownParser.writeSnippets(snippets, to: snippetsURL)
    }

    func removeSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        try? MarkdownParser.writeSnippets(snippets, to: snippetsURL)
    }

    // MARK: - Commands

    func addCommand(title: String, command: String, kind: QuickCommand.Kind) {
        commands.append(QuickCommand(title: title, command: command, kind: kind))
        let commandsURL = directoryURL.appendingPathComponent("_commands.md")
        try? MarkdownParser.writeCommands(commands, to: commandsURL)
    }

    func removeCommand(_ command: QuickCommand) {
        commands.removeAll { $0.id == command.id }
        let commandsURL = directoryURL.appendingPathComponent("_commands.md")
        try? MarkdownParser.writeCommands(commands, to: commandsURL)
    }

    // MARK: - Section Collapse State

    func isSectionCollapsed(_ section: String) -> Bool {
        UserDefaults.standard.bool(forKey: "noodl.section.\(section).collapsed")
    }

    func setSectionCollapsed(_ section: String, collapsed: Bool) {
        UserDefaults.standard.set(collapsed, forKey: "noodl.section.\(section).collapsed")
    }

    // MARK: - Directory

    func updateDirectory(_ url: URL) {
        directoryURL = url
        stopWatching()
        reload()
        startWatching()
    }

    // MARK: - Private

    private func writeBack(_ project: TodoProject) {
        try? MarkdownParser.write(project)
    }

    private func startWatching() {
        let watcher = FileWatcher(url: directoryURL)
        watcher.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.reload()
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    private func stopWatching() {
        watcher?.stop()
        watcher = nil
    }
}
