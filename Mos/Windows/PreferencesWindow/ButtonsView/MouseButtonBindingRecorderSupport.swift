//
//  MouseButtonBindingRecorderSupport.swift
//  Mos
//

import Foundation

enum MouseButtonBindingRecorderSupport {
    static func normalizedRecordedEventForButtonBinding(from event: InputEvent) -> RecordedEvent {
        let recordedEvent = RecordedEvent(from: event)
        let diagnosis = LogiCenter.shared.buttonCaptureDiagnosis(forMosCode: event.code)
        return recordedEvent.normalizedForButtonBinding(diagnosis: diagnosis)
    }

    static func isMouseGestureTriggerAvailable(_ event: InputEvent, existingBindings: [ButtonBinding]) -> Bool {
        guard event.type == .mouse,
              !KeyCode.mouseMainKeys.contains(event.code) else {
            return false
        }
        let recordedEvent = normalizedRecordedEventForButtonBinding(from: event)
        return !existingBindings.contains(where: { $0.triggerEvent == recordedEvent })
    }
}
