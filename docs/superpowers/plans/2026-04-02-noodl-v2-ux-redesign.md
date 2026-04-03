# Noodl v2 UX Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Noodl's tabbed interface with a unified scrollable stream, add a sticky pill bar for navigation, make Cmd+V always create a todo in the last expanded project, add a unified [+] add form with type picker, collapsible sections with persisted state, and a configurable global hotkey.

**Architecture:** Single `ScrollViewReader` stream replaces `PopoverTab` switching. `PillBar` provides quick-jump navigation with counts. `SectionHeader` is a reusable collapsible header. `UnifiedAddView` replaces `AddTodoView` with a type picker for Todo/Snippet/Command. `GlobalHotkey` registers a system-wide shortcut. `TodoStore` gains `lastExpandedProject` tracking and methods for adding snippets/commands.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 15+, Tuist, `@Observable`, `NSEvent` global/local monitors, `UserDefaults`, `ScrollViewReader`

**Spec:** `docs/superpowers/specs/2026-04-02-noodl-v2-ux-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Noodl/Sources/Services/TodoStore.swift` | Modify | Add `lastExpandedProject`, `pasteAsTodo()`, `addSnippet()`, `addCommand()`, section collapse state. Remove `quickPaste()`. |
| `Noodl/Sources/Services/MarkdownParser.swift` | Modify | Add `writeCommands(_:to:)` method |
| `Noodl/Sources/Views/PillBar.swift` | Create | Sticky pill bar with 3 jump buttons + counts |
| `Noodl/Sources/Views/SectionHeader.swift` | Create | Reusable collapsible section header |
| `Noodl/Sources/Views/StreamView.swift` | Create | ScrollViewReader with all 3 sections |
| `Noodl/Sources/Views/UnifiedAddView.swift` | Create | Type picker (Todo/Snippet/Command) + adaptive form |
| `Noodl/Sources/Views/PopoverView.swift` | Rewrite | Header + PillBar + StreamView, Cmd+V handler |
| `Noodl/Sources/Views/ProjectSection.swift` | Modify | Report expand/collapse to store via `lastExpandedProject` |
| `Noodl/Sources/Services/GlobalHotkey.swift` | Create | System-wide keyboard shortcut to open popover |
| `Noodl/Sources/Views/SettingsView.swift` | Modify | Add hotkey configuration |
| `Noodl/Sources/NoodlApp.swift` | Modify | Init GlobalHotkey, adjust popover size |
| `Noodl/Sources/Views/AddTodoView.swift` | Delete | Replaced by UnifiedAddView |

---

### Task 1: Add `writeCommands` to MarkdownParser

**Files:**
- Modify: `Noodl/Sources/Services/MarkdownParser.swift`

- [ ] **Step 1: Add writeCommands method**

Add this method after `writeSnippets` in `MarkdownParser.swift`:

```swift
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
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/lukaspribik/Documents/Work/personal/noodl-app && xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Services/MarkdownParser.swift
git commit -m "feat: add writeCommands to MarkdownParser"
```

---

### Task 2: Update TodoStore — lastExpandedProject, addSnippet, addCommand, section state

**Files:**
- Modify: `Noodl/Sources/Services/TodoStore.swift`

- [ ] **Step 1: Add new properties and remove quickPaste**

Replace the properties section and add new methods. The full updated `TodoStore.swift`:

```swift
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

        // Parse snippets from _snippets.md
        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        snippets = MarkdownParser.parseSnippets(url: snippetsURL)

        // Parse commands from _commands.md
        let commandsURL = directoryURL.appendingPathComponent("_commands.md")
        commands = MarkdownParser.parseCommands(url: commandsURL)

        // Parse todo projects (skip system files)
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

    /// Paste clipboard text as a todo to lastExpandedProject (or Inbox fallback).
    @discardableResult
    func pasteAsTodo() -> String? {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Use lastExpandedProject, fall back to Inbox
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
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/lukaspribik/Documents/Work/personal/noodl-app && xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"`

Expected: Build will fail because PopoverView still references `quickPaste()`. That's fine — we'll fix it in Task 5. For now verify there are no errors IN TodoStore itself by checking the error messages reference PopoverView, not TodoStore.

- [ ] **Step 3: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Services/TodoStore.swift
git commit -m "feat: update TodoStore — pasteAsTodo, addSnippet, addCommand, section state"
```

---

### Task 3: Create PillBar and SectionHeader views

**Files:**
- Create: `Noodl/Sources/Views/PillBar.swift`
- Create: `Noodl/Sources/Views/SectionHeader.swift`

- [ ] **Step 1: Create PillBar.swift**

```swift
import SwiftUI

enum NoodlSection: String, CaseIterable {
    case todos
    case snippets
    case commands

    var icon: String {
        switch self {
        case .todos: "checkmark.square"
        case .snippets: "doc.on.clipboard"
        case .commands: "bolt"
        }
    }
}

struct PillBar: View {
    let todoCount: Int
    let snippetCount: Int
    let commandCount: Int
    var activeSection: NoodlSection = .todos
    var onTap: (NoodlSection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            pill(.todos, count: todoCount)
            pill(.snippets, count: snippetCount)
            pill(.commands, count: commandCount)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func pill(_ section: NoodlSection, count: Int) -> some View {
        let isActive = activeSection == section
        return Button {
            onTap(section)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: section.icon)
                    .font(.system(size: 9))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Create SectionHeader.swift**

```swift
import SwiftUI

struct SectionHeader: View {
    let section: NoodlSection
    let title: String
    let count: Int
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `cd /Users/lukaspribik/Documents/Work/personal/noodl-app && tuist generate 2>&1 | tail -3`

Then: `xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"`

Expected: Build will still fail due to PopoverView. PillBar and SectionHeader should have no errors of their own.

- [ ] **Step 4: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/PillBar.swift Noodl/Sources/Views/SectionHeader.swift
git commit -m "feat: add PillBar and SectionHeader views"
```

---

### Task 4: Create UnifiedAddView

**Files:**
- Create: `Noodl/Sources/Views/UnifiedAddView.swift`
- Delete: `Noodl/Sources/Views/AddTodoView.swift`

- [ ] **Step 1: Create UnifiedAddView.swift**

```swift
import SwiftUI

enum AddItemType: String, CaseIterable {
    case todo = "Todo"
    case snippet = "Snippet"
    case command = "Command"
}

struct UnifiedAddView: View {
    var store: TodoStore
    @Binding var isShowing: Bool

    @State private var itemType: AddItemType = .todo
    @State private var title = ""
    @State private var content = ""
    @State private var selectedProjectIndex = 0
    @State private var priority: TodoItem.Priority? = nil
    @State private var commandKind: QuickCommand.Kind = .shell
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Type picker
            Picker("", selection: $itemType) {
                ForEach(AddItemType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Title field (always shown)
            TextField("Title…", text: $title)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onSubmit { addItem() }
                .padding(.horizontal, 12)

            // Content field (snippet and command only)
            if itemType == .snippet || itemType == .command {
                TextEditor(text: $content)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 60)
                    .padding(.horizontal, 12)
                    .scrollContentBackground(.hidden)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 12)
            }

            // Context pickers
            HStack(spacing: 8) {
                if itemType == .todo {
                    // Project picker
                    if !store.projects.isEmpty {
                        Picker("", selection: $selectedProjectIndex) {
                            ForEach(store.projects.indices, id: \.self) { index in
                                Text(store.projects[index].name).tag(index)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    // Priority picker
                    Picker("", selection: $priority) {
                        Text("None").tag(Optional<TodoItem.Priority>.none)
                        Text("!high").tag(Optional<TodoItem.Priority>.some(.high))
                        Text("!low").tag(Optional<TodoItem.Priority>.some(.low))
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }

                if itemType == .command {
                    Picker("Kind", selection: $commandKind) {
                        Text("Shell").tag(QuickCommand.Kind.shell)
                        Text("AI").tag(QuickCommand.Kind.ai)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }
            .padding(.horizontal, 12)

            // Action buttons
            HStack(spacing: 8) {
                Button("Add") { addItem() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear { isTitleFocused = true }
    }

    private func addItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        switch itemType {
        case .todo:
            guard !store.projects.isEmpty else { return }
            let project = store.projects[selectedProjectIndex]
            store.add(title: trimmedTitle, priority: priority, to: project)
        case .snippet:
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            store.addSnippet(title: trimmedTitle, content: trimmedContent.isEmpty ? trimmedTitle : trimmedContent)
        case .command:
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else { return }
            store.addCommand(title: trimmedTitle, command: trimmedContent, kind: commandKind)
        }

        // Clear for next entry
        title = ""
        content = ""
        priority = nil
        isTitleFocused = true
    }

    private func dismiss() {
        title = ""
        content = ""
        priority = nil
        isShowing = false
    }
}
```

- [ ] **Step 2: Delete AddTodoView.swift**

```bash
rm /Users/lukaspribik/Documents/Work/personal/noodl-app/Noodl/Sources/Views/AddTodoView.swift
```

- [ ] **Step 3: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/UnifiedAddView.swift
git rm Noodl/Sources/Views/AddTodoView.swift
git commit -m "feat: add UnifiedAddView, delete AddTodoView"
```

---

### Task 5: Create StreamView and rewrite PopoverView

**Files:**
- Create: `Noodl/Sources/Views/StreamView.swift`
- Rewrite: `Noodl/Sources/Views/PopoverView.swift`
- Modify: `Noodl/Sources/Views/ProjectSection.swift`

- [ ] **Step 1: Update ProjectSection to report expand/collapse**

Replace `ProjectSection.swift` with:

```swift
import SwiftUI

struct ProjectSection: View {
    let project: TodoProject
    var store: TodoStore
    @State private var isExpanded: Bool

    init(project: TodoProject, store: TodoStore) {
        self.project = project
        self.store = store
        self._isExpanded = State(initialValue: project.openCount > 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
                if isExpanded {
                    store.lastExpandedProject = project
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)

                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if project.openCount > 0 {
                        Text("\(project.openCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                let openItems = project.items.filter { !$0.isDone }
                let doneItems = project.items.filter { $0.isDone }

                ForEach(openItems) { item in
                    TodoRow(item: item, project: project, store: store)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                if !doneItems.isEmpty {
                    ForEach(doneItems) { item in
                        TodoRow(item: item, project: project, store: store)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear {
            if isExpanded {
                store.lastExpandedProject = project
            }
        }
    }
}
```

- [ ] **Step 2: Create StreamView.swift**

```swift
import SwiftUI

struct StreamView: View {
    var store: TodoStore
    @Binding var activeSection: NoodlSection
    @State private var todosCollapsed: Bool
    @State private var snippetsCollapsed: Bool
    @State private var commandsCollapsed: Bool

    init(store: TodoStore, activeSection: Binding<NoodlSection>) {
        self.store = store
        self._activeSection = activeSection
        self._todosCollapsed = State(initialValue: store.isSectionCollapsed("todos"))
        self._snippetsCollapsed = State(initialValue: store.isSectionCollapsed("snippets"))
        self._commandsCollapsed = State(initialValue: store.isSectionCollapsed("commands"))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // TODOS
                    SectionHeader(
                        section: .todos,
                        title: "Todos",
                        count: store.totalOpen,
                        isCollapsed: $todosCollapsed
                    )
                    .id(NoodlSection.todos)
                    .onChange(of: todosCollapsed) { _, val in store.setSectionCollapsed("todos", collapsed: val) }

                    if !todosCollapsed {
                        if store.projects.isEmpty {
                            Text("No projects")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.projects) { project in
                                ProjectSection(project: project, store: store)
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // SNIPPETS
                    SectionHeader(
                        section: .snippets,
                        title: "Snippets",
                        count: store.snippets.count,
                        isCollapsed: $snippetsCollapsed
                    )
                    .id(NoodlSection.snippets)
                    .onChange(of: snippetsCollapsed) { _, val in store.setSectionCollapsed("snippets", collapsed: val) }

                    if !snippetsCollapsed {
                        if store.snippets.isEmpty {
                            Text("No snippets")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.snippets) { snippet in
                                SnippetRow(snippet: snippet, store: store)
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // COMMANDS
                    SectionHeader(
                        section: .commands,
                        title: "Commands",
                        count: store.commands.count,
                        isCollapsed: $commandsCollapsed
                    )
                    .id(NoodlSection.commands)
                    .onChange(of: commandsCollapsed) { _, val in store.setSectionCollapsed("commands", collapsed: val) }

                    if !commandsCollapsed {
                        if store.commands.isEmpty {
                            Text("No commands")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.commands) { command in
                                CommandRow(command: command)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: activeSection) { _, section in
                withAnimation {
                    proxy.scrollTo(section, anchor: .top)
                }
                // Auto-expand if collapsed
                switch section {
                case .todos: if todosCollapsed { todosCollapsed = false }
                case .snippets: if snippetsCollapsed { snippetsCollapsed = false }
                case .commands: if commandsCollapsed { commandsCollapsed = false }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Rewrite PopoverView.swift**

```swift
import SwiftUI
import AppKit

struct PopoverView: View {
    var store: TodoStore
    @State private var showAddForm = false
    @State private var activeSection: NoodlSection = .todos
    @State private var keyMonitor: Any?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Noodl")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showAddForm.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Add item")

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Pill bar
            PillBar(
                todoCount: store.totalOpen,
                snippetCount: store.snippets.count,
                commandCount: store.commands.count,
                activeSection: activeSection
            ) { section in
                activeSection = section
            }

            Divider()

            // Unified add form
            if showAddForm {
                UnifiedAddView(store: store, isShowing: $showAddForm)
                Divider()
            }

            // Stream
            StreamView(store: store, activeSection: $activeSection)
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "v",
                   !showAddForm {
                    if store.pasteAsTodo() != nil {
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            keyMonitor = nil
        }
    }
}
```

- [ ] **Step 4: Regenerate Tuist and build**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
tuist generate 2>&1 | tail -3
xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

Fix any compilation errors (likely minor issues with types or missing imports).

- [ ] **Step 5: Run the app and verify unified stream**

```bash
pkill -f Noodl.app 2>/dev/null; sleep 0.5
open $(find ~/Library/Developer/Xcode/DerivedData/Noodl-*/Build/Products/Debug/Noodl.app -maxdepth 0 2>/dev/null | head -1)
```

Verify:
- All 3 sections visible in one scroll
- Pill bar shows counts
- Clicking pills scrolls to sections
- Sections collapse/expand
- Cmd+V adds todo to last expanded project
- [+] opens unified form with type picker

- [ ] **Step 6: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/StreamView.swift Noodl/Sources/Views/PopoverView.swift Noodl/Sources/Views/ProjectSection.swift
git commit -m "feat: unified stream layout — replace tabs with ScrollViewReader + PillBar"
```

---

### Task 6: Create GlobalHotkey and update Settings

**Files:**
- Create: `Noodl/Sources/Services/GlobalHotkey.swift`
- Modify: `Noodl/Sources/Views/SettingsView.swift`
- Modify: `Noodl/Sources/NoodlApp.swift`

- [ ] **Step 1: Create GlobalHotkey.swift**

```swift
import AppKit
import Carbon.HIToolbox

@MainActor
@Observable
final class GlobalHotkey {
    var isEnabled: Bool = false
    var modifierFlags: UInt = 0
    var keyCode: UInt16 = 0

    private var monitor: Any?

    var shortcutDescription: String {
        guard isEnabled, keyCode != 0 else { return "Not set" }
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if let char = keyCodeToString(keyCode) {
            parts.append(char.uppercased())
        }
        return parts.joined()
    }

    init() {
        loadFromDefaults()
        if isEnabled { startListening() }
    }

    func setShortcut(flags: NSEvent.ModifierFlags, code: UInt16) {
        modifierFlags = flags.rawValue
        keyCode = code
        isEnabled = true
        saveToDefaults()
        stopListening()
        startListening()
    }

    func clearShortcut() {
        isEnabled = false
        modifierFlags = 0
        keyCode = 0
        saveToDefaults()
        stopListening()
    }

    private func startListening() {
        guard isEnabled, keyCode != 0 else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let expectedFlags = NSEvent.ModifierFlags(rawValue: self.modifierFlags)
                .intersection([.control, .option, .shift, .command])
            let actualFlags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            if event.keyCode == self.keyCode && actualFlags == expectedFlags {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func loadFromDefaults() {
        let d = UserDefaults.standard
        isEnabled = d.bool(forKey: "noodl.hotkey.enabled")
        modifierFlags = UInt(d.integer(forKey: "noodl.hotkey.modifiers"))
        keyCode = UInt16(d.integer(forKey: "noodl.hotkey.keyCode"))
    }

    private func saveToDefaults() {
        let d = UserDefaults.standard
        d.set(isEnabled, forKey: "noodl.hotkey.enabled")
        d.set(Int(modifierFlags), forKey: "noodl.hotkey.modifiers")
        d.set(Int(keyCode), forKey: "noodl.hotkey.keyCode")
    }

    private func keyCodeToString(_ code: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        return data.withUnsafeBytes { ptr -> String? in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeyState: UInt32 = 0
            var length: Int = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(base, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, 4, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
```

- [ ] **Step 2: Update SettingsView.swift**

Replace the full file:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var store: TodoStore
    var hotkey: GlobalHotkey
    @State private var directoryPath = ""
    @State private var launchAtLogin = false
    @State private var isRecordingHotkey = false

    var body: some View {
        Form {
            Section("Directory") {
                HStack {
                    TextField("Noodl directory", text: $directoryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browseForDirectory() }
                }
                Text("Markdown files in this directory become projects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Open Noodl")
                    Spacer()
                    if isRecordingHotkey {
                        Text("Press shortcut…")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Text(hotkey.shortcutDescription)
                            .foregroundStyle(.secondary)
                    }
                    Button(isRecordingHotkey ? "Cancel" : "Record") {
                        isRecordingHotkey.toggle()
                    }
                    .controlSize(.small)
                    if hotkey.isEnabled {
                        Button("Clear") { hotkey.clearShortcut() }
                            .controlSize(.small)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Noodl")
                    Spacer()
                    Text("Noodle on your tasks.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
        .onAppear {
            directoryPath = store.directoryURL.path(percentEncoded: false)
            launchAtLogin = (try? SMAppService.mainApp.status == .enabled) ?? false
        }
        .onChange(of: directoryPath) { _, newPath in
            store.updateDirectory(URL(filePath: newPath))
        }
        .onKeyPress { keyPress in
            guard isRecordingHotkey else { return .ignored }
            let flags = NSEvent.ModifierFlags(rawValue: keyPress.modifiers.rawValue)
            // Require at least one modifier
            let mods = flags.intersection([.control, .option, .shift, .command])
            guard !mods.isEmpty else { return .ignored }
            // We can't get keyCode from SwiftUI KeyPress directly,
            // so we'll use NSEvent monitor instead
            return .ignored
        }
        .task(id: isRecordingHotkey) {
            guard isRecordingHotkey else { return }
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
                guard !mods.isEmpty else { return event }
                self.hotkey.setShortcut(flags: event.modifierFlags, code: event.keyCode)
                self.isRecordingHotkey = false
                return nil
            }
            // Clean up when recording stops
            while isRecordingHotkey {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path(percentEncoded: false)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
    }
}
```

- [ ] **Step 3: Update NoodlApp.swift**

```swift
import SwiftUI

@main
struct NoodlApp: App {
    @State private var store = TodoStore()
    @State private var hotkey = GlobalHotkey()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .frame(width: 320, height: 520)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                if store.totalOpen > 0 {
                    Text("\(store.totalOpen)")
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, hotkey: hotkey)
        }
    }
}
```

- [ ] **Step 4: Regenerate Tuist and build**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
tuist generate 2>&1 | tail -3
xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

Fix any compilation errors.

- [ ] **Step 5: Run and verify everything**

```bash
pkill -f Noodl.app 2>/dev/null; sleep 0.5
open $(find ~/Library/Developer/Xcode/DerivedData/Noodl-*/Build/Products/Debug/Noodl.app -maxdepth 0 2>/dev/null | head -1)
```

Full verification checklist:
1. Unified stream — all 3 sections in one scroll, no tabs
2. Pill bar — click each pill, scrolls to section, active highlights
3. Cmd+V — copy text, expand FixIt, paste → todo in FixIt
4. Cmd+V fallback — collapse all, paste → todo in Inbox
5. [+] form — type picker switches between Todo/Snippet/Command
6. Add snippet — title + content, appears in Snippets section
7. Add command — title + command, appears in Commands section
8. Collapse sections — collapse Snippets, reopen Noodl → still collapsed
9. Global hotkey — set in Settings, switch app, trigger → Noodl opens
10. Animations — paste slides in, delete fades out, toggle animates checkbox

- [ ] **Step 6: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Services/GlobalHotkey.swift Noodl/Sources/Views/SettingsView.swift Noodl/Sources/NoodlApp.swift
git commit -m "feat: global hotkey + settings integration"
```

---

### Task 7: Final cleanup and push

**Files:**
- All modified files

- [ ] **Step 1: Full build verification**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
tuist generate 2>&1 | tail -3
xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run app and do smoke test**

Launch the app and manually verify the 10-point checklist from Task 6 Step 5.

- [ ] **Step 3: Push to GitHub**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git push
```
