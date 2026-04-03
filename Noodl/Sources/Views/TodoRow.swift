import SwiftUI
import AppKit

struct TodoRow: View {
    let item: TodoItem
    let project: TodoProject
    var store: TodoStore
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox + title (tappable to toggle)
            Button {
                store.toggle(item, in: project)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)

                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .lineLimit(2)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Copy button (separate, doesn't trigger toggle)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(copied ? Color.green : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")

            // Priority badge
            if let priority = item.priority {
                PriorityBadge(priority: priority)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                store.remove(item, from: project)
            } label: {
                Label("Delete", systemImage: "trash")
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
