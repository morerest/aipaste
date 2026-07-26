import AppKit
import Carbon

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var handlerInstalled = false
    private(set) var current: HotKeyConfig = .default

    var onToggleHistory: (() -> Void)?

    func register(_ config: HotKeyConfig = .default) {
        uninstallHotKeyOnly()
        current = config

        ensureHandlerInstalled()

        var hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), /* 'CLIP' */ id: 1)
        let status = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            NSLog("aipaste hotkey register failed: \(status) for \(config.displayString)")
            hotKeyRef = nil
            return
        }
    }

    /// Returns whether Carbon accepted the registration (caller may revert UI on failure).
    @discardableResult
    func tryRegister(_ config: HotKeyConfig) -> Bool {
        uninstallHotKeyOnly()
        current = config
        ensureHandlerInstalled()

        var hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let status = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("aipaste hotkey register failed: \(status) for \(config.displayString)")
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        uninstallHotKeyOnly()
    }

    private func uninstallHotKeyOnly() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func ensureHandlerInstalled() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hk = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hk
                )
                if hk.id == 1 {
                    DispatchQueue.main.async { manager.onToggleHistory?() }
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handler
        )
        if status == noErr {
            handlerInstalled = true
        } else {
            NSLog("aipaste hotkey handler install failed: \(status)")
        }
    }

    deinit {
        uninstallHotKeyOnly()
        if let handler {
            RemoveEventHandler(handler)
        }
    }
}
