import Foundation
import Observation

@MainActor
@Observable
final class TodoStore {
    var projects: [TodoProject] = []
    var directoryURL: URL

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
            return
        }

        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil))
            ?? []

        let parsed = urls
            .filter { $0.pathExtension == "md" }
            .compactMap { MarkdownParser.parse(url: $0) }
            .sorted { lhs, rhs in
                // Inbox always last
                if lhs.name.lowercased() == "inbox" { return false }
                if rhs.name.lowercased() == "inbox" { return true }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }

        projects = parsed
    }

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

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        try? MarkdownParser.createEmpty(name: name, at: fileURL)
        reload()
    }

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
