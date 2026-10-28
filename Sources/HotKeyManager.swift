import Foundation
import Carbon
import AppKit

public class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onTrigger: (() -> Void)?
    
    private init() {
        installCarbonHandler()
    }
    
    public func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.onTrigger = action
        
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534E5458) // 'SNTX'
        hotKeyID.id = UInt32(1)
        
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status != noErr {
            print("[HotKeyManager] Failed to register hotkey: \(status)")
        } else {
            print("[HotKeyManager] Registered global hotkey keyCode=\(keyCode), mod=\(modifiers)")
        }
    }
    
    private func installCarbonHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetEventDispatcherTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            HotKeyManager.shared.onTrigger?()
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }
}
