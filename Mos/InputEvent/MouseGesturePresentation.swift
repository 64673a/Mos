//
//  MouseGesturePresentation.swift
//  Mos
//

import Cocoa

struct MouseGestureActionPresentation {
    let title: String
    let icon: NSImage?

    static let unbound = MouseGestureActionPresentation(
        title: NSLocalizedString("unbound", comment: ""),
        icon: nil
    )
}

enum MouseGesturePresentationResolver {
    static func resolve(action: MouseGestureAction?) -> MouseGestureActionPresentation {
        let presentation = ActionDisplayResolver().resolve(action: action)
        return MouseGestureActionPresentation(
            title: presentation.title,
            icon: pureIcon(for: presentation, pointSize: 20)
        )
    }

    static func resolve(actions: [MouseGestureDirection: MouseGestureAction]) -> [MouseGestureDirection: MouseGestureActionPresentation] {
        var result: [MouseGestureDirection: MouseGestureActionPresentation] = [:]
        for direction in MouseGestureDirection.allCases {
            guard let action = actions[direction], action.isTriggerAction else { continue }
            result[direction] = resolve(action: action)
        }
        return result
    }

    private static func pureIcon(for presentation: ActionPresentation, pointSize: CGFloat) -> NSImage? {
        switch presentation.kind {
        case .unbound, .recordingPrompt:
            return nil
        case .namedAction:
            guard #available(macOS 11.0, *), let symbolName = presentation.symbolName else { return nil }
            let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            return symbol?.withSymbolConfiguration(config) ?? symbol
        case .keyCombo:
            guard #available(macOS 11.0, *) else { return nil }
            let symbol = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            return symbol?.withSymbolConfiguration(config) ?? symbol
        case .openTarget:
            return presentation.image.map { resize($0, height: pointSize) }
        }
    }

    private static func resize(_ image: NSImage, height: CGFloat) -> NSImage {
        guard image.size.height > 0 else { return image }
        let scale = height / image.size.height
        let size = NSSize(width: image.size.width * scale, height: height)
        let resized = NSImage(size: size)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        resized.unlockFocus()
        resized.isTemplate = image.isTemplate
        return resized
    }
}
