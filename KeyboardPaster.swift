// Keyboard Paster: a floating on-screen keyboard that types into whatever field currently has focus
// (browser, any app). The panel never takes focus, so the cursor stays where it is.
//
// Global hotkeys (work while any app is focused):
//   ⌘F  capture the current clipboard text into the keyboard's buffer
//   ⌘G  type the buffer as keystrokes into the focused field

import Cocoa
import ApplicationServices
import Carbon.HIToolbox

// MARK: - Typing

enum Key {
    static let tab: CGKeyCode = 48
    static let enter: CGKeyCode = 36
    static let backspace: CGKeyCode = 51
    static let left: CGKeyCode = 123
    static let right: CGKeyCode = 124
}

enum Typer {
    static let source = CGEventSource(stateID: .hidSystemState)

    static func press(_ keyCode: CGKeyCode) {
        post(keyCode: keyCode, unicode: nil)
    }

    static func type(_ text: String) {
        for ch in text {
            switch ch {
            case "\n", "\r", "\r\n": press(Key.enter)
            case "\t": press(Key.tab)
            default: post(keyCode: 0, unicode: Array(String(ch).utf16))
            }
        }
    }

    /// Waits until ⌘/⇧/⌃/⌥ are released so a held hotkey modifier doesn't turn typed text into shortcuts.
    static func waitForModifierRelease(timeout: TimeInterval = 2) {
        let mask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        let deadline = Date().addingTimeInterval(timeout)
        while !CGEventSource.flagsState(.hidSystemState).intersection(mask).isEmpty && Date() < deadline {
            usleep(10_000)
        }
    }

    private static func post(keyCode: CGKeyCode, unicode: [UniChar]?) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            event.flags = []
            if let unicode {
                event.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode)
            }
            event.post(tap: .cghidEventTap)
        }
        usleep(3000)  // some web apps drop keys that arrive too fast
    }
}

// MARK: - Hotkeys

/// System-wide hotkeys via Carbon's RegisterEventHotKey (no extra permission needed).
final class HotKeys {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData!).takeUnretainedValue()
            hotKeys.handlers[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Returns false if the combination is already taken by another app.
    @discardableResult
    func register(keyCode: Int, modifiers: Int, _ handler: @escaping () -> Void) -> Bool {
        let id = UInt32(handlers.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers),
                                         EventHotKeyID(signature: OSType(0x4B425053), id: id),  // 'KBPS'
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        handlers[id] = handler
        refs.append(ref)
        return true
    }
}

// MARK: - UI

/// A panel that can be clicked without becoming key, so the target app keeps focus.
final class KeyboardPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ActionButton: NSButton {
    private var handler: () -> Void = {}

    static func make(_ title: String, width: CGFloat? = 34, _ handler: @escaping () -> Void) -> ActionButton {
        let button = ActionButton(title: title, target: nil, action: nil)
        button.handler = handler
        button.target = button
        button.action = #selector(fire)
        button.bezelStyle = .smallSquare
        button.font = .systemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        if let width {
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return button
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func fire() { handler() }
}

final class KeyboardController: NSObject, NSWindowDelegate {
    private let panel = KeyboardPanel(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 250),
        styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
        backing: .buffered, defer: false)
    private let root = NSStackView()
    private let status = NSTextField(labelWithString: "")
    private let bufferStatus = NSTextField(labelWithString: "Buffer empty — copy text, then ⌘F to capture it")
    private var charKeys: [(button: ActionButton, normal: String, shifted: String)] = []
    private var shift = false
    private let hotKeys = HotKeys()
    private var buffer = ""
    private let typingQueue = DispatchQueue(label: "KeyboardPaster.typing")

    // (normal, shifted) per row — Swedish layout
    private let charRows: [(String, String)] = [
        ("1234567890+", "!\"#¤%&/()=?"),
        ("qwertyuiopå", "QWERTYUIOPÅ"),
        ("asdfghjklöä", "ASDFGHJKLÖÄ"),
        ("zxcvbnm,.-@", "ZXCVBNM;:_@"),
    ]

    func show() {
        panel.title = "Keyboard Paster"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.delegate = self

        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 4
        root.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let rowViews = charRows.map { normal, shifted in
            zip(normal, shifted).map { n, s -> ActionButton in
                let (n, s) = (String(n), String(s))
                let button = ActionButton.make(n) { [weak self] in self?.typeChar(normal: n, shifted: s) }
                charKeys.append((button, n, s))
                return button
            }
        }

        root.addArrangedSubview(row(rowViews[0] + [ActionButton.make("⌫", width: 52) { Typer.press(Key.backspace) }]))
        root.addArrangedSubview(row([ActionButton.make("⇥", width: 52) { Typer.press(Key.tab) }] + rowViews[1]))
        root.addArrangedSubview(row(rowViews[2] + [ActionButton.make("⏎", width: 52) { Typer.press(Key.enter) }]))
        root.addArrangedSubview(row([ActionButton.make("⇧", width: 52) { [weak self] in self?.toggleShift() }] + rowViews[3]))
        root.addArrangedSubview(row([
            ActionButton.make("←", width: 52) { Typer.press(Key.left) },
            ActionButton.make("space", width: 300) { Typer.type(" ") },
            ActionButton.make("→", width: 52) { Typer.press(Key.right) },
        ]))

        for label in [bufferStatus, status] {
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            root.addArrangedSubview(label)
        }
        registerHotKeys()

        panel.contentView = root
        resize()
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - panel.frame.width / 2, y: screen.minY + 40))
        }
        panel.orderFrontRegardless()

        checkAccessibility(prompt: true)
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAccessibility(prompt: false)
        }
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 4
        return stack
    }

    private func resize() {
        panel.setContentSize(root.fittingSize)
    }

    // Change the key codes (kVK_ANSI_*) / modifiers (cmdKey, optionKey, controlKey, shiftKey) here.
    private func registerHotKeys() {
        let capture = hotKeys.register(keyCode: kVK_ANSI_F, modifiers: cmdKey) { [weak self] in self?.captureClipboard() }
        let type = hotKeys.register(keyCode: kVK_ANSI_G, modifiers: cmdKey) { [weak self] in self?.typeBuffer() }
        if !capture || !type {
            bufferStatus.stringValue = "⚠︎ Could not register ⌘F / ⌘G — another app already uses them"
        }
    }

    private func captureClipboard() {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            bufferStatus.stringValue = "Clipboard has no text"
            NSSound.beep()
            return
        }
        // Drop trailing newlines so typing doesn't press Enter and submit the form.
        buffer = String(text.reversed().drop(while: \.isNewline).reversed())
        // The buffer may be a password: take it off the clipboard so it can't be pasted or picked up later.
        pasteboard.clearContents()
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        bufferStatus.stringValue = "Captured \(buffer.count) characters at \(time), clipboard cleared — ⌘G to type"
        NSSound(named: "Tink")?.play()
    }

    private func typeBuffer() {
        guard !buffer.isEmpty else {
            NSSound.beep()
            return
        }
        let text = buffer
        typingQueue.async {
            Typer.waitForModifierRelease()
            Typer.type(text)
        }
    }

    private func typeChar(normal: String, shifted: String) {
        Typer.type(shift ? shifted : normal)
        if shift { toggleShift() }  // one-shot shift
    }

    private func toggleShift() {
        shift.toggle()
        for key in charKeys {
            key.button.title = shift ? key.shifted : key.normal
        }
    }

    private func checkAccessibility(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            status.stringValue = "Click a field in your browser, then press keys or ⌘G."
        } else {
            status.stringValue = "⚠︎ Grant Accessibility access: System Settings › Privacy & Security › Accessibility"
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Main

/// Quits any older copy so a single instance owns the ⌘F/⌘G hotkeys and the buffer.
func terminateOtherInstances() {
    let me = ProcessInfo.processInfo.processIdentifier
    let pgrep = Process()
    let pipe = Pipe()
    pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    pgrep.arguments = ["-x", ProcessInfo.processInfo.processName]
    pgrep.standardOutput = pipe
    guard (try? pgrep.run()) != nil else { return }
    pgrep.waitUntilExit()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let others = output.split(separator: "\n").compactMap { pid_t($0) }.filter { $0 != me }
    others.forEach { kill($0, SIGTERM) }
    let deadline = Date().addingTimeInterval(2)
    while others.contains(where: { kill($0, 0) == 0 }) && Date() < deadline {
        usleep(20_000)
    }
}

// Never write anything (clipboard contents, errors, system noise) to the console.
freopen("/dev/null", "w", stdout)
freopen("/dev/null", "w", stderr)

terminateOtherInstances()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = KeyboardController()
controller.show()
app.run()
