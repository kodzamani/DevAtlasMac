import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Carbon's hot keys work while another app is frontmost and,
/// unlike event taps, need no Accessibility permission.
final class GlobalHotKey {
    private static var nextID: UInt32 = 1

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let id: UInt32
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// - Parameters:
    ///   - keyCode: A virtual key code such as `kVK_Space`.
    ///   - modifiers: Carbon modifier flags such as `controlKey`.
    init(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.handler = handler
        self.id = Self.nextID
        Self.nextID += 1
    }

    deinit { unregister() }

    /// Returns false when the shortcut could not be claimed, for example because another app holds it.
    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressed
            )
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            guard status == noErr, pressed.signature == GlobalHotKey.signature, pressed.id == hotKey.id else {
                return OSStatus(eventNotHandledErr)
            }
            hotKey.handler()
            return noErr
        }, 1, &eventType, context, &handlerRef)
        guard installStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    /// "DVAT", so our events are told apart from other hot keys in the process.
    private static let signature: OSType = {
        "DVAT".utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }()
}
