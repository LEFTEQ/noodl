# Noodl v3 Phase 1: Two-Column Layout + Cmd+V Snippet Paste

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Noodl from a single-column 320px popover to a two-column 480px layout (empty memory sidebar on left, tools stream on right), and change Cmd+V from creating a todo to creating a snippet with an inline editable name field.

**Architecture:** `PopoverView` becomes an `HStack` with `MemorySidebar` (left, 38%) and the existing tools stream (right, 62%). `MemorySidebar` is a placeholder shell for Phase 2 (screenshots/voice). `SnippetRow` gains an "editing" mode for the inline name field on newly pasted snippets. `TodoStore.pasteAsTodo()` is replaced by `pasteAsSnippet()`. `NoodlApp` frame widens to 480×520.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 15+, `@Observable`, `NSEvent`, `NSPasteboard`

**Spec:** `docs/superpowers/specs/2026-04-02-noodl-v3-daily-capture.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Noodl/Sources/Views/MemorySidebar.swift` | Create | Left column: date header, placeholder for screenshots/voice (Phase 2), date nav |
| `Noodl/Sources/Views/PopoverView.swift` | Modify | HStack with MemorySidebar + tools column. Cmd+V calls pasteAsSnippet |
| `Noodl/Sources/Services/TodoStore.swift` | Modify | Replace `pasteAsTodo()` with `pasteAsSnippet()`. Add `editingSnippetId` |
| `Noodl/Sources/Views/SnippetRow.swift` | Modify | Add inline editable name mode for newly pasted snippets |
| `Noodl/Sources/Views/StreamView.swift` | Modify | Scroll to snippets section and expand it on paste |
| `Noodl/Sources/NoodlApp.swift` | Modify | Frame 480×520 |

---

### Task 1: Create MemorySidebar placeholder

**Files:**
- Create: `Noodl/Sources/Views/MemorySidebar.swift`

- [ ] **Step 1: Create MemorySidebar.swift**

Create file at `/Users/lukaspribik/Documents/Work/personal/noodl-app/Noodl/Sources/Views/MemorySidebar.swift`:

```swift
import SwiftUI

struct MemorySidebar: View {
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Memory")
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.day().month().year())
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Placeholder for Phase 2 content
            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("Screenshots & voice\ncoming soon")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Divider()

            // Date navigation footer
            HStack {
                Button {
                    // Phase 2: navigate to yesterday
                } label: {
                    Text("← Yesterday")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Today")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Tomorrow →")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/MemorySidebar.swift
git commit -m "feat: add MemorySidebar placeholder for two-column layout"
```

---

### Task 2: Update TodoStore — replace pasteAsTodo with pasteAsSnippet

**Files:**
- Modify: `Noodl/Sources/Services/TodoStore.swift`

- [ ] **Step 1: Add editingSnippetId and replace paste method**

In `TodoStore.swift`, add a new property after `lastExpandedProject`:

```swift
    var editingSnippetId: UUID?
```

Then replace the entire `pasteAsTodo()` method (lines 90-114) with:

```swift
    /// Paste clipboard text as a new snippet with editable name.
    /// Returns the snippet ID if successful, nil if clipboard was empty.
    @discardableResult
    func pasteAsSnippet() -> UUID? {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = String(trimmed.components(separatedBy: .newlines).first?.prefix(40) ?? trimmed.prefix(40))

        let snippet = Snippet(title: defaultTitle, content: trimmed)
        snippets.insert(snippet, at: 0)
        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        try? MarkdownParser.writeSnippets(snippets, to: snippetsURL)

        editingSnippetId = snippet.id
        return snippet.id
    }

    /// Update a snippet's title (used by inline edit after paste).
    func renameSnippet(_ snippet: Snippet, to newTitle: String) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        snippets[index] = Snippet(id: snippet.id, title: trimmed, content: snippet.content)
        let snippetsURL = directoryURL.appendingPathComponent("_snippets.md")
        try? MarkdownParser.writeSnippets(snippets, to: snippetsURL)
        if editingSnippetId == snippet.id {
            editingSnippetId = nil
        }
    }
```

- [ ] **Step 2: Build to verify**

Run: `cd /Users/lukaspribik/Documents/Work/personal/noodl-app && xcodebuild -scheme Noodl -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"`

Expected: Build fails because PopoverView still calls `pasteAsTodo()`. That's expected.

- [ ] **Step 3: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Services/TodoStore.swift
git commit -m "feat: replace pasteAsTodo with pasteAsSnippet + renameSnippet"
```

---

### Task 3: Update SnippetRow with inline editable name

**Files:**
- Modify: `Noodl/Sources/Views/SnippetRow.swift`

- [ ] **Step 1: Replace SnippetRow.swift**

Replace the entire content of `/Users/lukaspribik/Documents/Work/personal/noodl-app/Noodl/Sources/Views/SnippetRow.swift`:

```swift
import SwiftUI
import AppKit

struct SnippetRow: View {
    let snippet: Snippet
    var store: TodoStore
    @State private var copied = false
    @State private var editingTitle: String = ""
    @FocusState private var isEditingFocused: Bool

    private var isEditing: Bool {
        store.editingSnippetId == snippet.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(copied ? .green : .secondary)
                .frame(width: 14)

            if isEditing {
                // Inline editable name
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Snippet name…", text: $editingTitle)
                        .font(.system(size: 12, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($isEditingFocused)
                        .onSubmit { commitRename() }
                    Text(snippet.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                // Normal display
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(snippet.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isEditing ? Color.accentColor.opacity(0.06) : Color.clear)
        .onTapGesture {
            guard !isEditing else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet.content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet.content, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                editingTitle = snippet.title
                store.editingSnippetId = snippet.id
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                store.removeSnippet(snippet)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                editingTitle = snippet.title
                isEditingFocused = true
                // Auto-accept after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if store.editingSnippetId == snippet.id {
                        commitRename()
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func commitRename() {
        let name = editingTitle.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            store.renameSnippet(snippet, to: name)
        } else {
            store.editingSnippetId = nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/SnippetRow.swift
git commit -m "feat: add inline editable name to SnippetRow for paste workflow"
```

---

### Task 4: Update PopoverView — two-column layout + Cmd+V as snippet

**Files:**
- Modify: `Noodl/Sources/Views/PopoverView.swift`

- [ ] **Step 1: Replace PopoverView.swift**

Replace the entire content of `/Users/lukaspribik/Documents/Work/personal/noodl-app/Noodl/Sources/Views/PopoverView.swift`:

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
        HStack(spacing: 0) {
            // Left column: Memory sidebar
            MemorySidebar()
                .frame(width: 180)

            Divider()

            // Right column: Tools
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
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "v",
                   !showAddForm {
                    if store.pasteAsSnippet() != nil {
                        // Scroll to snippets section
                        activeSection = .snippets
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

- [ ] **Step 2: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/Views/PopoverView.swift
git commit -m "feat: two-column layout + Cmd+V pastes as snippet"
```

---

### Task 5: Update NoodlApp frame + build + verify

**Files:**
- Modify: `Noodl/Sources/NoodlApp.swift`

- [ ] **Step 1: Update frame to 480×520**

In `NoodlApp.swift`, change the frame line:

```swift
            PopoverView(store: store)
                .frame(width: 480, height: 520)
```

- [ ] **Step 2: Regenerate Tuist and build**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
tuist generate 2>&1 | tail -3
xcodebuild -scheme Noodl -destination 'platform=macOS' clean build 2>&1 | grep -E "(error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **`

Fix any errors. Common issues:
- `Color.quaternary` might not exist — use `Color.secondary.opacity(0.3)` instead
- `.textCase(.uppercase)` needs macOS 14+ (we target 15, so fine)
- SwiftUI `@FocusState` in `SnippetRow` needs the view to be focusable

- [ ] **Step 3: Run and verify**

```bash
pkill -f Noodl.app 2>/dev/null; sleep 0.5
open $(find ~/Library/Developer/Xcode/DerivedData/Noodl-*/Build/Products/Debug/Noodl.app -maxdepth 0 2>/dev/null | sort | tail -1)
```

Verify:
1. Popover is wider (480px) with two columns
2. Left column shows "Today's Memory" with date and placeholder
3. Right column has the tools stream (todos, snippets, commands)
4. Cmd+V: copy text, open Noodl, paste → new snippet appears in Snippets section with editable name
5. Editable name field is focused, can type a new name, press Enter to confirm
6. After 3 seconds without edit, name auto-accepts
7. Click a snippet to copy (still works)
8. Context menu has Copy, Rename, Delete

- [ ] **Step 4: Commit**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git add Noodl/Sources/NoodlApp.swift
git commit -m "feat: widen popover to 480px for two-column layout"
```

---

### Task 6: Push to GitHub

- [ ] **Step 1: Push**

```bash
cd /Users/lukaspribik/Documents/Work/personal/noodl-app
git push
```
