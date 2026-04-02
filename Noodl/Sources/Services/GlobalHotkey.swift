import AppKit

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
        let map: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j", 40: "k",
            45: "n", 46: "m"
        ]
        return map[code]
    }
}
