import Foundation

struct TodoItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var isDone: Bool
    var priority: Priority?

    enum Priority: String, CaseIterable, Sendable {
        case high = "!high"
        case low = "!low"
    }

    init(id: UUID = UUID(), title: String, isDone: Bool = false, priority: Priority? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.priority = priority
    }
}
