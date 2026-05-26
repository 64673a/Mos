//
//  MouseGestureController.swift
//  Mos
//

import Cocoa

enum MouseGestureResult: Equatable {
    case consumed
    case passthrough
}

final class MouseGestureController {
    static let shared = MouseGestureController()

    private var session: MouseGestureSession?
    private var overlay: MouseGestureOverlayWindow?
    private var motionInterceptor: Interceptor?
    private var suppressedTriggerAfterCancel: RecordedEvent?
    private let motionEventMask =
        CGEventMask(1 << CGEventType.mouseMoved.rawValue) |
        CGEventMask(1 << CGEventType.leftMouseDragged.rawValue) |
        CGEventMask(1 << CGEventType.rightMouseDragged.rawValue) |
        CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)

    init() {}

    func process(_ event: InputEvent) -> MouseGestureResult {
        if event.isEscapeKeyDown {
            cancel(suppressTriggerUp: true)
            return .consumed
        }

        if event.phase == .up,
           matchesTrigger(event, trigger: suppressedTriggerAfterCancel) {
            suppressedTriggerAfterCancel = nil
            return .consumed
        }
        if event.phase == .up {
            suppressedTriggerAfterCancel = nil
        }

        if let session {
            return processActiveSession(event, session: session)
        }

        guard event.phase == .down,
              let config = currentConfig(),
              matchesTrigger(event, trigger: config.triggerEvent) else {
            return .passthrough
        }

        beginSession(event: event, config: config)
        return .consumed
    }

    func handleMouseMoved(to location: CGPoint) -> MouseGestureResult {
        guard let session else { return .passthrough }
        let selected = session.hitTester.direction(at: location)
        self.session?.selectedDirection = selected
        overlay?.update(mouseLocation: location, selectedDirection: selected)
        return .consumed
    }

    func cancel(suppressTriggerUp: Bool = false) {
        if suppressTriggerUp {
            suppressedTriggerAfterCancel = session?.triggerEvent
        }
        session = nil
        stopMotionTracking()
        overlay?.closeOverlay()
        overlay = nil
    }

    private func processActiveSession(_ event: InputEvent, session: MouseGestureSession) -> MouseGestureResult {
        guard matchesTrigger(event, trigger: session.triggerEvent) else {
            return .passthrough
        }

        if event.phase == .up {
            finish(session)
        }
        return .consumed
    }

    private func beginSession(event: InputEvent, config: MouseGestureOptions) {
        guard let triggerEvent = config.triggerEvent else { return }
        let directions = Set(MouseGestureDirection.allCases.filter { config.action(for: $0) != nil })
        guard !directions.isEmpty else { return }
        let mouseLocation = NSEvent.mouseLocation
        let overlay = MouseGestureOverlayWindow()
        overlay.show(
            at: mouseLocation,
            directions: directions,
            presentations: MouseGesturePresentationResolver.resolve(actions: config.directions)
        )
        startMotionTracking()

        let hitTester = MouseGestureHitTester(center: overlay.gestureCenter, enabledDirections: directions)
        self.overlay = overlay
        self.session = MouseGestureSession(
            triggerEvent: triggerEvent,
            actions: config.directions,
            hitTester: hitTester,
            selectedDirection: nil
        )
    }

    private func finish(_ session: MouseGestureSession) {
        let selected = session.selectedDirection
        cancel()
        guard let direction = selected,
              let action = session.actions[direction],
              action.isTriggerAction else {
            return
        }
        execute(action)
    }

    private func execute(_ gestureAction: MouseGestureAction) {
        let binding: ButtonBinding
        let trigger = RecordedEvent(type: .mouse, code: 3, modifiers: 0, displayComponents: [], deviceFilter: nil)
        if let openTarget = gestureAction.openTarget {
            binding = ButtonBinding(triggerEvent: trigger, openTarget: openTarget)
        } else {
            binding = ButtonBinding(triggerEvent: trigger, systemShortcutName: gestureAction.systemShortcutName, isEnabled: true)
        }
        guard let action = ShortcutExecutor.shared.resolveAction(
            named: gestureAction.systemShortcutName,
            binding: binding
        ), action.executionMode == .trigger else {
            return
        }
        ShortcutExecutor.shared.execute(action: action, phase: .down)
    }

    private func currentConfig() -> MouseGestureOptions? {
        let config = Options.shared.mouseGesture.config
        return config.isEnabled ? config : nil
    }

    private func matchesTrigger(_ event: InputEvent, trigger: RecordedEvent?) -> Bool {
        guard let trigger,
              trigger.type == .mouse,
              event.type == .mouse,
              event.code == trigger.code else {
            return false
        }
        if let filter = trigger.deviceFilter {
            return filter.matches(event.device)
        }
        return true
    }

    private func startMotionTracking() {
        guard motionInterceptor == nil else { return }
        do {
            motionInterceptor = try Interceptor(
                event: motionEventMask,
                handleBy: { _, type, event, _ in
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        MouseGestureController.shared.cancel()
                        return Unmanaged.passUnretained(event)
                    }
                    if event.getIntegerValueField(.eventSourceUserData) == MosEventMarker.syntheticCustom {
                        return Unmanaged.passUnretained(event)
                    }
                    switch MouseGestureController.shared.handleMouseMoved(to: NSEvent.mouseLocation) {
                    case .consumed:
                        return nil
                    case .passthrough:
                        return Unmanaged.passUnretained(event)
                    }
                },
                listenOn: .cgAnnotatedSessionEventTap,
                placeAt: .tailAppendEventTap,
                for: .defaultTap
            )
            motionInterceptor?.onRestart = {
                MouseGestureController.shared.cancel()
            }
        } catch {
            NSLog("MouseGestureController: Failed to create motion interceptor: \(error)")
            cancel()
        }
    }

    private func stopMotionTracking() {
        motionInterceptor?.stop()
        motionInterceptor = nil
    }
}

private struct MouseGestureSession {
    let triggerEvent: RecordedEvent
    let actions: [MouseGestureDirection: MouseGestureAction]
    let hitTester: MouseGestureHitTester
    var selectedDirection: MouseGestureDirection?
}

private extension InputEvent {
    var isEscapeKeyDown: Bool {
        return type == .keyboard && code == KeyCode.escape && phase == .down
    }
}
