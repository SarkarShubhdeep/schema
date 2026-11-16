//
//  GlobalHotKey.swift
//  Schema
//
//  A system-wide keyboard shortcut through Carbon's RegisterEventHotKey.
//  It works in the sandbox and needs no Accessibility permission, unlike
//  monitoring every key press.
//

import Carbon.HIToolbox
import Foundation
import os

private let hotKeyLog = Logger(subsystem: "com.sarkarshubhdeep.schema", category: "hotkey")

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    /// `keyCode` is a virtual key code (kVK_*); `modifiers` are Carbon masks (controlKey, optionKey, …).
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if let action = GlobalHotKey.actions[hotKeyID.id] {
                DispatchQueue.main.async(execute: action)
            }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        guard installStatus == noErr else {
            hotKeyLog.error("Could not install the hot key handler: \(installStatus)")
            return nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5343_484D), id: id) // "SCHM"
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            hotKeyLog.error("Could not register the hot key (another app may use it): \(status)")
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        Self.actions[id] = nil
    }
}
