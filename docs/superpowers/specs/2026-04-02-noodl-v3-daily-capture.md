# Noodl v3 — Daily Capture Hub

## Summary

Noodl evolves from a single-column tools app into a two-column daily capture hub. Left column = "Today's Memory" (screenshots, voice recordings). Right column = persistent tools (todos, snippets, commands). Cmd+V adds a snippet (with editable name) — no separate clipboard history. The popover widens to 480px with a 40/60 split. New global shortcuts for screenshots via macOS `screencapture`. Built-in voice recording via `AVAudioRecorder`. Daily memory folders organized by date (DD-MM-YYYY). All Claude Code commands move to the `noodl:` namespace. New `/noodl:memory` command summarizes and answers questions about a day's captures using AI vision and transcription.

## Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| App identity | Quick memory + tools | Two distinct halves: ephemeral daily captures and persistent tools |
| Layout | 40/60 two-column split | Memory sidebar (left), tools workspace (right). 480px popover width |
| Cmd+V behavior | Adds clipboard content as a new snippet | Inline editable name field appears. Content = clipboard text. Fast capture to persistent snippets |
| Screenshots | Custom global shortcut → `screencapture -i` | Files go directly to today's dated folder. Noodl detects via FileWatcher |
| Voice recording | Built-in AVAudioRecorder | Record button in memory sidebar. Saves .m4a to today's folder |
| Daily storage | `~/noodl/memory/DD-MM-YYYY/` | screenshots + voice notes per day. Inside noodl directory |
| Date navigation | ← Yesterday / Today / Tomorrow → | Footer of memory column. Browse past days |
| Command namespace | `noodl:*` prefix | noodl:todo, noodl:snippet, noodl:command, noodl:memory |
| AI summary | /noodl:memory with Q&A | No args = summary. With question = AI answers from screenshots/voice |
| Popover size | 480×520 | Wide enough for two columns, tall enough for stream |

## Architecture

### Two-Column PopoverView

```
┌──────────────────────────────────────────────────┐
│ [Left: Memory 38%]  │  [Right: Tools 62%]        │
│                      │                            │
│ 🧠 Today's Memory    │  Noodl            [+] [⚙]  │
│ 02.04.2026 [Summary] │  [☑ 5] [📋 3] [⚡ 5]       │
│                      │                            │
│ SCREENSHOTS (2)      │  ☑ TODOS            [▾]   │
│ ┌────┐ ┌────┐        │    ▼ FixIt (2)             │
│ │ 🖼 │ │ 🖼 │        │      ○ Fix geolocation     │
│ └────┘ └────┘        │      ○ Update push tokens  │
│                      │    ▸ Inbox (3)             │
│ VOICE (1)            │                            │
│ 🎙 0:42 ━━━━━━       │  📋 SNIPPETS         [▾]   │
│                      │    SSH VPS                  │
│ [🎤 Record]          │    Docker Restart           │
│                      │    [new pasted snippet...]  │
│                      │                            │
│                      │  ⚡ COMMANDS         [▾]   │
│                      │    ▶ Deploy Status          │
│                      │    ✦ Analyze Errors   AI   │
│                      │                            │
│ ◀ Yesterday  Today   │                            │
└──────────────────────────────────────────────────┘
```

### Components to Create

**New views:**
- `MemorySidebar.swift` — left column container: date header, Summarize button, screenshot grid, voice list, record button, date nav
- `ScreenshotGrid.swift` — 2-column grid of screenshot thumbnails. Click to preview/open in Finder
- `VoiceRow.swift` — voice note with duration, playback progress bar. Click to play
- `RecordButton.swift` — toggle recording state (idle/recording with timer)
- `DateNavigator.swift` — ← Yesterday / Today / Tomorrow → footer
- `SummaryPanel.swift` — shows AI summary result (from Summarize button or /noodl:memory)

**New services:**
- `MemoryStore.swift` — `@Observable`, manages daily memory: screenshots, voice notes. Handles date navigation, file watching for today's folder
- `ScreenshotService.swift` — registers global shortcut, runs `screencapture -i <path>`, manages screenshot files
- `VoiceRecorder.swift` — wraps `AVAudioRecorder`, manages recording state, saves to today's folder

**Modified views:**
- `PopoverView.swift` — two-column `HStack`: `MemorySidebar` (left) + existing tools stream (right)
- `NoodlApp.swift` — init MemoryStore, ScreenshotService. Pass to PopoverView. Frame 480×520

**New commands (Claude Code):**
- `~/.claude/commands/noodl/todo.md` — thin dispatcher (rename from me:todolist)
- `~/.claude/commands/noodl/snippet.md` — thin dispatcher (rename from me:snippet)
- `~/.claude/commands/noodl/command.md` — add/list/remove commands
- `~/.claude/commands/noodl/memory.md` — summarize + Q&A daily captures
- Spec files in `noodl-app/.claude/` for each command

**Deleted commands:**
- `~/.claude/commands/me/todolist.md` — replaced by noodl:todo
- `~/.claude/commands/me/snippet.md` — replaced by noodl:snippet

### Data Storage

```
~/Documents/Work/personal/noodl/
├── Inbox.md                    # Todo project
├── FixIt.md                    # Todo project
├── _snippets.md                # Persistent snippets
├── _commands.md                # Persistent commands
└── memory/
    ├── 01-04-2026/
    │   ├── screenshot-143022.png
    │   ├── screenshot-154500.png
    │   └── voice-150311.m4a
    └── 02-04-2026/
        ├── screenshot-091545.png
        └── voice-101200.m4a
```

### Cmd+V Flow

```
User hits Cmd+V (popover open, not in text field)
  → Read NSPasteboard.general string
  → If empty, ignore
  → Create new snippet: content = clipboard text, title = first line (truncated)
  → Show inline editable name field on the new snippet row (auto-focused)
  → User can edit the name or press Enter to accept default
  → After 3 seconds without edit, auto-accepts the default name
  → Snippet persisted to _snippets.md
  → Animate: snippet slides into Snippets section
```

Cmd+V = quick snippet creation with editable name.

### Screenshot Flow

```
User hits screenshot shortcut (e.g. Ctrl+Shift+S)
  → ScreenshotService runs: screencapture -i <today_folder>/screenshot-HHMMSS.png
  → macOS crosshair appears
  → User selects area → file saved
  → FileWatcher detects new .png in today's folder
  → MemoryStore reloads → thumbnail appears in sidebar
```

### Voice Recording Flow

```
User clicks [🎤 Record]
  → VoiceRecorder starts AVAudioRecorder
  → Button shows 🔴 + elapsed timer
  → User clicks to stop
  → File saved: memory/DD-MM-YYYY/voice-HHMMSS.m4a
  → MemoryStore reloads → voice note appears in sidebar
```

### /noodl:memory Command

Thin dispatcher at `~/.claude/commands/noodl/memory.md`. Spec in `noodl-app/.claude/memory-spec.md`.

```
/noodl:memory                              # Summarize today
/noodl:memory 01-04-2026                   # Summarize specific day
/noodl:memory "what was the error?"        # Q&A about today
/noodl:memory 01-04-2026 "what did I do?"  # Q&A about specific day
```

The subagent:
1. Reads all `.png` files in the day's folder → uses vision to describe each screenshot
2. Reads all `.m4a` files → transcribes via Whisper CLI (local)
3. With no question: outputs structured daily summary
4. With question: answers based on all captured context (screenshots + voice transcripts)

### Global Shortcuts

| Shortcut | Action | Configurable |
|----------|--------|-------------|
| Hotkey 1 | Open Noodl popover | Yes (Settings) |
| Hotkey 2 | Take screenshot → today's folder | Yes (Settings) |

Both stored in UserDefaults, configurable via Record button in Settings.

## Resolved Questions

- **Voice transcription**: Use OpenAI Whisper (`whisper` CLI, runs locally) for transcription in /noodl:memory
- **Screenshot annotations**: No — keep simple. AI describes via vision in /noodl:memory
- **In-app summarize**: Yes — "Summarize" button in memory sidebar header runs `claude -p` in background, shows result in a panel
