import Foundation

struct TodoProject: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let filePath: URL
    var items: [TodoItem]

    var openCount: Int { items.filter { !$0.isDone }.count }
    var doneCount: Int { items.filter { $0.isDone }.count }
}
