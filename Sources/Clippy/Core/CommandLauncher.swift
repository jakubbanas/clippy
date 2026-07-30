import AppKit

/// Owns the single global hotkey. On press, runs the sole contributed command
/// directly — or, if more than one feature contributes a command, pops a menu to
/// pick between them. This replaces per-feature hotkeys, so there's only one combo
/// to register (and no cross-feature clashes).
final class CommandLauncher {
    private var hotKey: HotKey?
    private var commands: [Command] = []

    /// (Re)binds the hotkey and refreshes the command list. Safe to call on reload.
    func configure(hotkey: String, commands: [Command]) {
        self.commands = commands
        hotKey?.unregister()
        hotKey = nil
        guard let combo = HotKeyCombo.parse(hotkey) else {
            NSLog("Launcher: could not parse hotkey \"\(hotkey)\"")
            return
        }
        hotKey = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers) { [weak self] in
            self?.trigger()
        }
    }

    func stop() {
        hotKey?.unregister()
        hotKey = nil
    }

    private func trigger() {
        if commands.count == 1 {
            commands[0].perform()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        guard !commands.isEmpty else { return }
        let menu = NSMenu()
        for (index, command) in commands.enumerated() {
            let item = NSMenuItem(
                title: command.title,
                action: #selector(pick(_:)),
                keyEquivalent: index < 9 ? String(index + 1) : ""
            )
            item.target = self
            item.keyEquivalentModifierMask = [] // bare "1"/"2", not ⌘1
            item.tag = index
            menu.addItem(item)
        }
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func pick(_ sender: NSMenuItem) {
        guard commands.indices.contains(sender.tag) else { return }
        commands[sender.tag].perform()
    }
}
