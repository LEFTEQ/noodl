# Noodl v2 — UX Redesign Spec

## Summary

Noodl is a macOS menu bar quick-capture tool. v1 uses a tabbed interface (Todos/Snippets/Commands) which adds friction to the primary use case: fast capture via paste. v2 replaces tabs with a unified scrollable stream, adds a sticky pill bar for quick-jump navigation, makes Cmd+V always create a todo, and adds a global hotkey for instant access from any app.

## Decisions

| Question | Decision |
|----------|----------|
| App identity | Quick capture tool — speed is #1 |
| Navigation | Unified stream (no tabs) + sticky pill bar for jumping |
| Cmd+V behavior | Always creates a todo, regardless of scroll position |
| Todo paste target | Last expanded project (falls back to Inbox) |
| Adding snippets/commands | Via [+] button with type picker (Todo/Snippet/Command) |
| Section collapsibility | Collapsible with persisted state (UserDefaults) |
| Global hotkey | Configurable shortcut to open popover from anywhere |
| Action feedback | Inline animations only (slide in, fade out, flash). No toasts. |

## Architecture

### Unified Stream Layout

Replace `PopoverTab` enum and segmented picker with a single `ScrollViewReader` containing all three sections stacked vertically:

```
┌─────────────────────────────┐
│ Noodl                [+] [⚙]│  Header
├─────────────────────────────┤
│  [☑ 5]  [📋 3]  [⚡ 5]     │  Pill bar (sticky, clickable, shows counts)
├─────────────────────────────┤
│ ☑ TODOS              [▾]   │  Section header (collapsible)
│   ▼ FixIt (2)               │
│     ○ Fix geolocation  high │
│     ○ Update push tokens    │
│   ▸ Inbox (3)               │
│                             │
│ 📋 SNIPPETS           [▾]   │  Section header (collapsible)
│   ⧉ SSH VPS                 │
│   ⧉ Docker Restart          │
│                             │
│ ⚡ COMMANDS            [▾]   │  Section header (collapsible)
│   ▶ Deploy Status           │
│   ▶ Crypto Logs             │
│   ✦ Analyze Errors    AI    │
└─────────────────────────────┘
```

### Components to Create/Modify

**New:**
- `StreamView.swift` — replaces the tab-switching logic in PopoverView. Single ScrollViewReader with section IDs for pill-bar jumping.
- `PillBar.swift` — horizontal bar with 3 pill buttons. Each shows icon + count. Highlights active section based on scroll position. Clicking scrolls to section.
- `SectionHeader.swift` — reusable collapsible header with icon, title, count, and chevron. Stores expanded/collapsed state in UserDefaults keyed by section name.
- `UnifiedAddView.swift` — replaces AddTodoView. Has a type picker (Todo/Snippet/Command) that adapts the form fields:
  - Todo: project picker + title + priority
  - Snippet: title + content (multiline)
  - Command: title + command (multiline) + kind picker (shell/ai)
- `GlobalHotkey.swift` — registers a configurable global keyboard shortcut via `NSEvent.addGlobalMonitorForEvents`. Opens/focuses the MenuBarExtra popover. Shortcut stored in UserDefaults, configurable in Settings.

**Modified:**
- `PopoverView.swift` — gutted and rebuilt. Remove tab enum, segmented picker, per-tab switching, toast overlay, NSEvent key monitor. Replace with: header + PillBar + StreamView.
- `TodoStore.swift` — remove `quickPaste()`. Add new methods:
  - `pasteAsTodo()` — reads clipboard, adds to last expanded project (tracked via new `lastExpandedProject: TodoProject?` property). Falls back to Inbox.
  - `addSnippet(title:content:)` — creates snippet and writes to `_snippets.md`.
  - `addCommand(title:command:kind:)` — creates command and writes to `_commands.md`.
  - `sectionCollapsed(_:)` / `setSectionCollapsed(_:Bool)` — UserDefaults-backed section state.
- `MarkdownParser.swift` — add `writeCommands(_:to:)` method for writing `_commands.md` (similar pattern to `writeSnippets`).
- `SettingsView.swift` — add global hotkey configuration field.
- `NoodlApp.swift` — initialize GlobalHotkey, potentially increase popover height to accommodate stream.

**Deleted:**
- `AddTodoView.swift` — replaced by UnifiedAddView.

**Unchanged:**
- `TodoRow.swift`, `SnippetRow.swift`, `CommandRow.swift` — existing row views work as-is in the stream.
- `ProjectSection.swift` — used inside the Todos section, unchanged.
- `FileWatcher.swift`, `CommandRunner.swift` — no changes needed.
- Models (`TodoItem`, `TodoProject`, `Snippet`, `QuickCommand`) — no changes.

### Cmd+V Flow

```
User hits Cmd+V (popover open, not in text field)
  → Read NSPasteboard.general string
  → If empty, ignore
  → Find store.lastExpandedProject (set when user expands a ProjectSection)
  → If nil, find Inbox project (create if needed)
  → Add todo with clipboard text as title (first line only)
  → Scroll to the new item
  → Animate: item slides in from right with 0.2s ease
```

The `lastExpandedProject` is tracked by observing ProjectSection expand/collapse. When a user expands a project, store records it. When they collapse it, if it was the last expanded, clear the reference. Multiple expanded = last one expanded wins.

Edge case: if the Todos section itself is collapsed, Cmd+V still works — it adds to `lastExpandedProject` (or Inbox) and auto-expands the Todos section to show the new item. The paste always succeeds regardless of UI state.

### Pill Bar Behavior

- 3 pills: `☑ {todoCount}`, `📋 {snippetCount}`, `⚡ {commandCount}`
- Active pill is highlighted (matches the section currently visible in scroll)
- Scroll position detection: use `ScrollViewReader` + `onAppear`/`onDisappear` on section header anchors
- Click a pill → `proxy.scrollTo(sectionID, anchor: .top)`
- Pills are always visible (sticky at top, not part of scroll content)

### Collapsible Sections

- Each of the 3 main sections (Todos, Snippets, Commands) has a collapse/expand chevron
- State persisted in UserDefaults: `noodl.section.todos.collapsed`, etc.
- Collapsed sections show only the header line (icon + title + count)
- Pill bar counts are always visible regardless of collapse state
- Within Todos, individual ProjectSections remain independently collapsible (existing behavior)

### [+] Unified Add Form

Appears inline below the header when [+] is clicked:

```
┌─────────────────────────────┐
│ [Todo●] [Snippet] [Command] │  Type picker (segmented)
│ ┌─────────────────────────┐ │
│ │ Title...                │ │  TextField (always shown)
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │  
│ │ Content...              │ │  TextEditor (snippet/command only)
│ └─────────────────────────┘ │
│ [Project▾] [Priority▾]     │  Pickers (todo only)
│ [Kind▾]                    │  Shell/AI picker (command only)
│ [Add]  [Cancel]            │
└─────────────────────────────┘
```

- Default type: Todo
- For Todo: show project picker + priority picker, hide content field
- For Snippet: show content field, hide project/priority pickers
- For Command: show content field + kind picker (shell/ai), hide project/priority
- After adding, clear form but keep it open for rapid entry
- Escape or Cancel closes the form

### Global Hotkey

- Uses `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` to listen for configurable shortcut
- Default: unset (user must configure in Settings)
- On trigger: activate the app and open the MenuBarExtra popover
- Opening the popover programmatically: `NSApp.activate(ignoringOtherApps: true)` + click the status item
- Settings shows a "Record Shortcut" button that captures the next key combo
- Stored in UserDefaults as modifier flags + key code

### Inline Animation Specs

| Action | Animation |
|--------|-----------|
| Paste/Add item | Item slides in from right, 0.2s ease-out, slight highlight flash |
| Toggle todo done | Checkbox morphs (circle → checkmark), text fades to secondary, 0.15s |
| Delete item | Item fades out + shrinks height, 0.2s ease-in |
| Copy snippet | Copy icon flashes green → checkmark for 1s, then reverts |
| Run command | Spinner appears on icon, result panel slides down on completion |

All animations use SwiftUI's `withAnimation(.easeOut(duration: 0.2))` or `.transition()` modifiers.

## Verification

1. **Unified stream**: Open Noodl → all 3 sections visible in single scroll, no tabs
2. **Pill bar**: Click each pill → scrolls to correct section. Active pill highlights on scroll.
3. **Cmd+V**: Copy text, open Noodl, expand FixIt, Cmd+V → todo appears in FixIt with slide animation
4. **Cmd+V fallback**: Collapse all projects, Cmd+V → todo goes to Inbox
5. **[+] form**: Click +, switch between Todo/Snippet/Command → form fields adapt correctly
6. **Add snippet via form**: Type title + content, click Add → appears in Snippets section
7. **Add command via form**: Type title + command, pick shell, click Add → appears in Commands section
8. **Collapse sections**: Collapse Snippets → only header visible. Reopen Noodl → still collapsed.
9. **Global hotkey**: Set shortcut in Settings, switch to another app, press shortcut → Noodl opens
10. **Animations**: Paste → item slides in. Delete → item fades out. Toggle → checkbox animates. No toasts appear.
11. **Build**: `tuist generate && xcodebuild -scheme Noodl -destination 'platform=macOS' build` succeeds
