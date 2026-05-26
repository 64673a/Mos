//
//  MouseGestureOverlayWindow.swift
//  Mos
//

import Cocoa

final class MouseGestureOverlayWindow: NSPanel {
    private let content = MouseGestureOverlayView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 176, height: 176),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = content
    }

    var gestureCenter: CGPoint {
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    func show(
        at mouseLocation: CGPoint,
        directions: Set<MouseGestureDirection>,
        presentations: [MouseGestureDirection: MouseGestureActionPresentation]
    ) {
        let targetFrame = Self.frameAround(mouseLocation: mouseLocation, size: frame.size)
        setFrame(targetFrame, display: true)
        content.enabledDirections = directions
        content.presentations = presentations
        content.setSelectedDirection(nil)
        content.startPoint = convertScreenPoint(mouseLocation)
        alphaValue = 0
        orderFrontRegardless()
        content.startOpenAnimation()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    func update(mouseLocation: CGPoint, selectedDirection: MouseGestureDirection?) {
        content.pointerPoint = convertScreenPoint(mouseLocation)
        content.setSelectedDirection(selectedDirection)
        content.needsDisplay = true
    }

    func closeOverlay() {
        orderOut(nil)
    }

    private func convertScreenPoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    private static func frameAround(mouseLocation: CGPoint, size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(origin: .zero, size: size)
        var origin = CGPoint(
            x: mouseLocation.x - size.width / 2,
            y: mouseLocation.y - size.height / 2
        )
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }
}

final class MouseGestureOverlayView: NSView {
    var enabledDirections: Set<MouseGestureDirection> = []
    var presentations: [MouseGestureDirection: MouseGestureActionPresentation] = [:]
    var startPoint: CGPoint?
    var pointerPoint: CGPoint?
    private var selectedDirection: MouseGestureDirection?
    private var previousSelectedDirection: MouseGestureDirection?
    private var openProgress: CGFloat = 1
    private var selectionPulse: CGFloat = 0

    override var isFlipped: Bool { return false }

    func startOpenAnimation() {
        openProgress = 0
        animate(duration: 0.14) { [weak self] progress in
            self?.openProgress = progress
            self?.needsDisplay = true
        }
    }

    func setSelectedDirection(_ direction: MouseGestureDirection?) {
        selectedDirection = direction
        guard direction != previousSelectedDirection else {
            needsDisplay = true
            return
        }
        previousSelectedDirection = direction
        selectionPulse = direction == nil ? 0 : 1
        guard direction != nil else {
            needsDisplay = true
            return
        }
        animate(duration: 0.16) { [weak self] progress in
            self?.selectionPulse = max(0, 1 - progress)
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let openScale = 0.88 + openProgress * 0.12
        let outerRadius: CGFloat = (min(bounds.width, bounds.height) / 2 - 12) * openScale
        let innerRadius = MouseGestureHitTester.cancelRadius
        let ringWidth = outerRadius - innerRadius

        for direction in MouseGestureDirection.allCases where enabledDirections.contains(direction) && direction != selectedDirection {
            drawSegment(
                direction,
                center: center,
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                highlighted: false
            )
        }
        if let selectedDirection, enabledDirections.contains(selectedDirection) {
            drawSegment(
                selectedDirection,
                center: center,
                innerRadius: innerRadius,
                outerRadius: outerRadius + selectedSegmentExpansion,
                highlighted: true
            )
        }
        for direction in MouseGestureDirection.allCases where enabledDirections.contains(direction) {
            let iconOuterRadius = direction == selectedDirection ? outerRadius + selectedSegmentExpansion : outerRadius
            drawIcon(direction, center: center, innerRadius: innerRadius, outerRadius: iconOuterRadius)
        }
        drawCenter(center: center, radius: innerRadius)
        if let startPoint {
            drawStartPoint(startPoint)
        }
        if let pointerPoint {
            drawPointer(point: pointerPoint, center: center, ringWidth: ringWidth)
        }
    }

    private func drawSegment(
        _ direction: MouseGestureDirection,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        highlighted: Bool
    ) {
        let path = segmentPath(direction, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
        let fill: NSColor
        if highlighted {
            let accentColor: NSColor
            if #available(macOS 10.14, *) {
                accentColor = .controlAccentColor
            } else {
                accentColor = .systemBlue
            }
            fill = accentColor.withAlphaComponent(0.68 + selectionPulse * 0.08)
        } else {
            fill = NSColor.black.withAlphaComponent(0.24)
        }

        if highlighted {
            drawSegmentGlow(path)
        }
        fill.setFill()
        path.fill()

        if highlighted {
            NSColor.white.withAlphaComponent(0.58).setStroke()
        } else {
            NSColor.white.withAlphaComponent(0.18).setStroke()
        }
        path.lineWidth = 1
        path.stroke()
    }

    private func segmentPath(
        _ direction: MouseGestureDirection,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> NSBezierPath {
        let angles = angleRange(for: direction)
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: outerRadius, startAngle: angles.start, endAngle: angles.end)
        path.appendArc(withCenter: center, radius: innerRadius, startAngle: angles.end, endAngle: angles.start, clockwise: true)
        path.close()
        return path
    }

    private func drawIcon(
        _ direction: MouseGestureDirection,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        guard let icon = presentations[direction]?.icon else { return }
        let angle = midAngle(for: direction) * .pi / 180
        let radius = (innerRadius + outerRadius) / 2
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        let highlighted = direction == selectedDirection
        let targetHeight: CGFloat = highlighted ? 24 + selectionPulse * 2 : 20
        let scale = icon.size.height > 0 ? targetHeight / icon.size.height : 1
        let width = min(icon.size.width * scale, 48)
        let rect = CGRect(x: point.x - width / 2, y: point.y - targetHeight / 2, width: width, height: targetHeight)

        if icon.isTemplate {
            let color = highlighted ? NSColor.white : NSColor.labelColor
            tintTemplateIcon(icon, in: rect, color: color, alpha: highlighted ? 0.95 : 0.76)
        } else {
            icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: highlighted ? 1 : 0.82)
        }
    }

    private var selectedSegmentExpansion: CGFloat {
        guard selectedDirection != nil else { return 0 }
        return 7 + selectionPulse * 2
    }

    private func drawSegmentGlow(_ path: NSBezierPath) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = .zero
        shadow.shadowColor = NSColor.systemBlue.withAlphaComponent(0.28)
        shadow.set()
        NSColor.systemBlue.withAlphaComponent(0.20).setFill()
        path.fill()
        context.restoreGState()
    }

    private func tintTemplateIcon(_ icon: NSImage, in rect: CGRect, color: NSColor, alpha: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let mask = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        context.saveGState()
        context.clip(to: rect, mask: mask)
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(rect: rect).fill()
        context.restoreGState()
    }

    private func angleRange(for direction: MouseGestureDirection) -> (start: CGFloat, end: CGFloat) {
        switch direction {
        case .right: return (-45, 45)
        case .up: return (45, 135)
        case .left: return (135, 225)
        case .down: return (225, 315)
        }
    }

    private func midAngle(for direction: MouseGestureDirection) -> CGFloat {
        let range = angleRange(for: direction)
        return (range.start + range.end) / 2
    }

    private func drawCenter(center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor.white.withAlphaComponent(0.24).setStroke()
        let outline = NSBezierPath(ovalIn: rect)
        outline.lineWidth = 1
        outline.stroke()
    }

    private func drawStartPoint(_ point: CGPoint) {
        NSColor.white.withAlphaComponent(0.70).setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
        NSColor.black.withAlphaComponent(0.18).setStroke()
        let outline = NSBezierPath(ovalIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
        outline.lineWidth = 1
        outline.stroke()
    }

    private func drawPointer(point: CGPoint, center: CGPoint, ringWidth: CGFloat) {
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: point)
        NSColor.white.withAlphaComponent(0.24).setStroke()
        path.lineWidth = max(1, min(1.6, ringWidth / 26))
        path.stroke()
    }

    private func animate(duration: TimeInterval, update: @escaping (CGFloat) -> Void) {
        let start = CACurrentMediaTime()
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - start
            let rawProgress = min(1, CGFloat(elapsed / duration))
            let easedProgress = 1 - CGFloat(pow(Double(1 - rawProgress), 3))
            update(easedProgress)
            if rawProgress >= 1 {
                timer.invalidate()
            }
        }
    }
}
