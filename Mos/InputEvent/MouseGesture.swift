//
//  MouseGesture.swift
//  Mos
//
//  Created by Codex on 2026/5/26.
//  Copyright © 2026 Caldis. All rights reserved.
//

import Cocoa

enum MouseGestureDirection: String, Codable, CaseIterable {
    case up
    case right
    case down
    case left

    var localizedName: String {
        return NSLocalizedString("mouse_gesture_direction_\(rawValue)", comment: "")
    }
}

struct MouseGestureAction: Codable, Equatable {
    let systemShortcutName: String
    let openTarget: OpenTargetPayload?

    static let unbound = MouseGestureAction(systemShortcutName: "", openTarget: nil)

    var isBound: Bool {
        return openTarget != nil || !systemShortcutName.isEmpty
    }

    var isTriggerAction: Bool {
        guard isBound else { return false }
        var binding = ButtonBinding(
            triggerEvent: RecordedEvent(type: .mouse, code: 3, modifiers: 0, displayComponents: [], deviceFilter: nil),
            systemShortcutName: systemShortcutName
        )
        if let openTarget {
            binding = ButtonBinding(
                triggerEvent: binding.triggerEvent,
                openTarget: openTarget
            )
        }
        binding.prepareCustomCache()
        guard let action = ShortcutExecutor.shared.resolveAction(named: systemShortcutName, binding: binding) else {
            return false
        }
        return action.executionMode == .trigger
    }

    init(systemShortcutName: String, openTarget: OpenTargetPayload? = nil) {
        self.systemShortcutName = systemShortcutName
        self.openTarget = openTarget
    }

    init(openTarget: OpenTargetPayload) {
        self.systemShortcutName = ButtonBinding.openTargetSentinel
        self.openTarget = openTarget
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decode(String.self, forKey: .systemShortcutName)
        let payload = try c.decodeIfPresent(OpenTargetPayload.self, forKey: .openTarget)
        let nameIsSentinel = name == ButtonBinding.openTargetSentinel
        let payloadIsPresent = payload != nil
        if nameIsSentinel != payloadIsPresent {
            throw DecodingError.dataCorruptedError(
                forKey: .openTarget,
                in: c,
                debugDescription: "Inconsistent MouseGestureAction: systemShortcutName=\"\(name)\" but openTarget \(payloadIsPresent ? "present" : "missing")"
            )
        }
        self.systemShortcutName = name
        self.openTarget = payload
    }

    enum CodingKeys: String, CodingKey {
        case systemShortcutName, openTarget
    }
}

struct MouseGestureOptions: Codable, Equatable {
    var triggerEvent: RecordedEvent?
    var directions: [MouseGestureDirection: MouseGestureAction]

    init(
        triggerEvent: RecordedEvent? = nil,
        directions: [MouseGestureDirection: MouseGestureAction] = [:]
    ) {
        self.triggerEvent = triggerEvent
        self.directions = directions
    }

    var isEnabled: Bool {
        guard let triggerEvent = triggerEvent,
              triggerEvent.type == .mouse,
              !KeyCode.mouseMainKeys.contains(triggerEvent.code) else {
            return false
        }
        return MouseGestureDirection.allCases.contains { direction in
            directions[direction]?.isTriggerAction == true
        }
    }

    func action(for direction: MouseGestureDirection) -> MouseGestureAction? {
        guard let action = directions[direction], action.isTriggerAction else { return nil }
        return action
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        triggerEvent = try c.decodeIfPresent(RecordedEvent.self, forKey: .triggerEvent)
        let rawDirections = try c.decodeIfPresent([String: MouseGestureAction].self, forKey: .directions) ?? [:]
        var decodedDirections: [MouseGestureDirection: MouseGestureAction] = [:]
        for (key, action) in rawDirections {
            guard let direction = MouseGestureDirection(rawValue: key) else { continue }
            decodedDirections[direction] = action
        }
        directions = decodedDirections
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(triggerEvent, forKey: .triggerEvent)
        var rawDirections: [String: MouseGestureAction] = [:]
        for (direction, action) in directions {
            rawDirections[direction.rawValue] = action
        }
        try c.encode(rawDirections, forKey: .directions)
    }

    enum CodingKeys: String, CodingKey {
        case triggerEvent, directions
    }
}

struct MouseGestureHitTester {
    static let activationDistance: CGFloat = 20.0
    static let cancelRadius = activationDistance

    let center: CGPoint
    let enabledDirections: Set<MouseGestureDirection>

    func direction(at point: CGPoint) -> MouseGestureDirection? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= Self.activationDistance else {
            return nil
        }

        let direction: MouseGestureDirection
        if abs(dx) > abs(dy) {
            direction = dx > 0 ? .right : .left
        } else {
            direction = dy > 0 ? .up : .down
        }
        return enabledDirections.contains(direction) ? direction : nil
    }
}
