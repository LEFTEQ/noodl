import SwiftUI

struct TodoRow: View {
    let item: TodoItem
    let project: TodoProject
    var store: TodoStore

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button {
                store.toggle(item, in: project)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            // Title
            Text(item.title)
                .font(.body)
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            // Priority badge
            if let priority = item.priority {
                PriorityBadge(priority: priority)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                store.remove(item, from: project)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct PriorityBadge: View {
    let priority: TodoItem.Priority

    var body: some View {
        Text(priority == .high ? "high" : "low")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(priority == .high ? Color.red.opacity(0.12) : Color.secondary.opacity(0.12))
            .foregroundStyle(priority == .high ? Color.red : Color.secondary)
            .clipShape(Capsule())
    }
}
