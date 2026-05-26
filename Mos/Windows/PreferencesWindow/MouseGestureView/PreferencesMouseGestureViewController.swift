//
//  PreferencesMouseGestureViewController.swift
//  Mos
//

import Cocoa

final class PreferencesMouseGestureViewController: NSViewController, KeyRecorderDelegate {
    private let recorder = KeyRecorder()
    private var config = MouseGestureOptions()
    private var actionButtons: [MouseGestureDirection: MouseGestureActionPopUpButton] = [:]
    private var triggerPreview: KeyPreview?
    private var previewView: MouseGesturePreviewView?
    private var currentOpenTargetPopover: OpenTargetConfigPopover?

    override func loadView() {
        let root = NSVisualEffectView()
        root.blendingMode = .behindWindow
        root.state = .followsWindowActiveState
        if #available(macOS 10.14, *) {
            root.material = .toolTip
        }
        root.frame = NSRect(x: 0, y: 0, width: 520, height: 392)
        view = root
        buildView(in: root)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        recorder.delegate = self
        loadOptionsToView()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadOptionsToView()
    }

    private func buildView(in root: NSView) {
        let title = NSTextField(labelWithString: NSLocalizedString("mouse_gesture_title", comment: ""))
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(title)

        let detail = NSTextField(wrappingLabelWithString: NSLocalizedString("mouse_gesture_detail", comment: ""))
        detail.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.preferredMaxLayoutWidth = 448
        detail.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(detail)

        let triggerLabel = formLabel(NSLocalizedString("mouse_gesture_trigger", comment: ""))
        root.addSubview(triggerLabel)

        let triggerPreview = KeyPreview()
        triggerPreview.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(triggerPreview)
        self.triggerPreview = triggerPreview

        let recordButton = NSButton(
            title: NSLocalizedString("mouse_gesture_record_trigger", comment: ""),
            target: self,
            action: #selector(recordTrigger(_:))
        )
        recordButton.bezelStyle = .rounded
        recordButton.controlSize = .small
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(recordButton)

        let clearButton = NSButton(
            title: NSLocalizedString("mouse_gesture_clear_trigger", comment: ""),
            target: self,
            action: #selector(clearTrigger(_:))
        )
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(clearButton)

        let preview = MouseGesturePreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(preview)
        previewView = preview

        var previousBottom = triggerPreview.bottomAnchor
        for direction in MouseGestureDirection.allCases {
            let label = formLabel(direction.localizedName)
            root.addSubview(label)

            let popup = MouseGestureActionPopUpButton(frame: .zero, pullsDown: false)
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.onChange = { [weak self] action in
                self?.updateAction(direction: direction, action: action)
            }
            popup.onOpenTargetSelectionRequested = { [weak self, weak popup] in
                guard let self = self, let popup = popup else { return }
                self.presentOpenTargetPopover(direction: direction, sourceView: popup)
            }
            root.addSubview(popup)
            actionButtons[direction] = popup

            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: triggerLabel.trailingAnchor),
                label.centerYAnchor.constraint(equalTo: popup.centerYAnchor),
                popup.topAnchor.constraint(equalTo: previousBottom, constant: 14),
                popup.leadingAnchor.constraint(equalTo: triggerPreview.leadingAnchor),
                popup.trailingAnchor.constraint(equalTo: preview.leadingAnchor, constant: -26),
                popup.heightAnchor.constraint(equalToConstant: 26)
            ])
            previousBottom = popup.bottomAnchor
        }

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 520),
            root.heightAnchor.constraint(equalToConstant: 392),

            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),

            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),

            triggerLabel.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 24),
            triggerLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            triggerLabel.widthAnchor.constraint(equalToConstant: 88),

            triggerPreview.leadingAnchor.constraint(equalTo: triggerLabel.trailingAnchor, constant: 14),
            triggerPreview.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),

            recordButton.topAnchor.constraint(equalTo: triggerLabel.topAnchor, constant: -5),
            recordButton.leadingAnchor.constraint(greaterThanOrEqualTo: triggerPreview.trailingAnchor, constant: 12),
            clearButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 8),
            clearButton.trailingAnchor.constraint(equalTo: preview.leadingAnchor, constant: -26),
            clearButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),

            preview.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -32),
            preview.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 28),
            preview.widthAnchor.constraint(equalToConstant: 168),
            preview.heightAnchor.constraint(equalToConstant: 168)
        ])
    }

    private func formLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func loadOptionsToView() {
        config = Options.shared.mouseGesture.config
        refreshView()
    }

    private func refreshView() {
        if let trigger = config.triggerEvent {
            triggerPreview?.update(from: trigger.displayComponents, status: .normal)
        } else {
            triggerPreview?.update(from: [NSLocalizedString("unbound", comment: "")], status: .normal)
        }

        let showLogiActions = config.triggerEvent.map {
            $0.type == .mouse && LogiCenter.shared.isLogiCode($0.code)
        } ?? false
        for direction in MouseGestureDirection.allCases {
            actionButtons[direction]?.configure(action: config.action(for: direction), showLogiActions: showLogiActions)
        }
        previewView?.configure(
            directions: Set(MouseGestureDirection.allCases.filter { config.action(for: $0) != nil }),
            presentations: MouseGesturePresentationResolver.resolve(actions: config.directions)
        )
    }

    private func syncViewWithOptions() {
        Options.shared.mouseGesture.config = config
        LogiCenter.shared.setUsage(source: .mouseGesture, codes: collectMouseGestureCodes())
        refreshView()
    }

    private func collectMouseGestureCodes() -> Set<UInt16> {
        guard let trigger = config.triggerEvent,
              trigger.type == .mouse,
              LogiCenter.shared.isLogiCode(trigger.code) else {
            return []
        }
        return [trigger.code]
    }

    @objc private func recordTrigger(_ sender: NSButton) {
        recorder.startRecording(from: sender, mode: .adaptive)
    }

    @objc private func clearTrigger(_ sender: NSButton) {
        config.triggerEvent = nil
        syncViewWithOptions()
    }

    private func updateAction(direction: MouseGestureDirection, action: MouseGestureAction?) {
        if let action, action.isTriggerAction {
            config.directions[direction] = action
        } else {
            config.directions.removeValue(forKey: direction)
        }
        syncViewWithOptions()
    }

    private func presentOpenTargetPopover(direction: MouseGestureDirection, sourceView: NSView) {
        let popover = OpenTargetConfigPopover()
        currentOpenTargetPopover = popover
        popover.onCommit = { [weak self] payload in
            guard let self = self else { return }
            self.updateAction(direction: direction, action: MouseGestureAction(openTarget: payload))
            self.currentOpenTargetPopover = nil
        }
        popover.onCancel = { [weak self] in
            self?.currentOpenTargetPopover = nil
        }
        popover.show(at: sourceView, existing: config.directions[direction]?.openTarget)
    }

    func validateRecordedEvent(_ recorder: KeyRecorder, event: InputEvent) -> Bool {
        return MouseButtonBindingRecorderSupport.isMouseGestureTriggerAvailable(
            event,
            existingBindings: Options.shared.buttons.binding
        )
    }

    func onEventRecorded(_ recorder: KeyRecorder, didRecordEvent event: InputEvent, isDuplicate: Bool) {
        let recorded = MouseButtonBindingRecorderSupport.normalizedRecordedEventForButtonBinding(from: event)
        let existingBindings = Options.shared.buttons.binding
        guard MouseButtonBindingRecorderSupport.isMouseGestureTriggerAvailable(event, existingBindings: existingBindings) else {
            if event.type == .mouse,
               !KeyCode.mouseMainKeys.contains(event.code),
               existingBindings.contains(where: { $0.triggerEvent == recorded }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + KeyRecorder.recordingFeedbackDelay(isDuplicate: true)) { [weak self] in
                    self?.showTriggerConflictAlert()
                }
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + KeyRecorder.recordingFeedbackDelay(isDuplicate: false)) { [weak self] in
            self?.config.triggerEvent = recorded
            self?.syncViewWithOptions()
        }
    }

    private func showTriggerConflictAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("mouse_gesture_trigger_conflict_title", comment: "")
        alert.informativeText = NSLocalizedString("mouse_gesture_trigger_conflict_detail", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private final class MouseGesturePreviewView: NSView {
    private var directions: Set<MouseGestureDirection> = []
    private var presentations: [MouseGestureDirection: MouseGestureActionPresentation] = [:]
    private var hoveredDirection: MouseGestureDirection?

    override var isFlipped: Bool { return false }

    func configure(
        directions: Set<MouseGestureDirection>,
        presentations: [MouseGestureDirection: MouseGestureActionPresentation]
    ) {
        self.directions = directions
        self.presentations = presentations
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredDirection = direction(at: point)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredDirection = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 - 6
        let innerRadius: CGFloat = 30

        for direction in MouseGestureDirection.allCases where directions.contains(direction) && direction != hoveredDirection {
            drawSegment(direction, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
        }
        if let hoveredDirection, directions.contains(hoveredDirection) {
            drawSegment(hoveredDirection, center: center, innerRadius: innerRadius, outerRadius: outerRadius + hoverExpansion)
        }
        for direction in MouseGestureDirection.allCases where directions.contains(direction) {
            let iconOuterRadius = direction == hoveredDirection ? outerRadius + hoverExpansion : outerRadius
            drawIcon(direction, center: center, innerRadius: innerRadius, outerRadius: iconOuterRadius)
        }

        if #available(macOS 10.14, *) {
            NSColor.controlBackgroundColor.withAlphaComponent(0.88).setFill()
        } else {
            NSColor.windowBackgroundColor.withAlphaComponent(0.88).setFill()
        }
        NSBezierPath(ovalIn: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )).fill()

    }

    private func drawSegment(
        _ direction: MouseGestureDirection,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        let highlighted = direction == hoveredDirection
        let path = segmentPath(direction, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
        let accentColor: NSColor
        if #available(macOS 10.14, *) {
            accentColor = .controlAccentColor
        } else {
            accentColor = .systemBlue
        }
        let color = highlighted
            ? accentColor.withAlphaComponent(0.68)
            : NSColor.black.withAlphaComponent(0.18)
        color.setFill()
        path.fill()
        if highlighted {
            NSColor.white.withAlphaComponent(0.50).setStroke()
        } else {
            NSColor.white.withAlphaComponent(0.18).setStroke()
        }
        path.lineWidth = 1
        path.stroke()
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
        let highlighted = direction == hoveredDirection
        let height: CGFloat = highlighted ? 25 : 21
        let scale = icon.size.height > 0 ? height / icon.size.height : 1
        let width = min(icon.size.width * scale, 50)
        let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
        if icon.isTemplate {
            let color = highlighted ? NSColor.white : NSColor.labelColor
            tintTemplateIcon(icon, in: rect, color: color, alpha: highlighted ? 0.95 : 0.74)
        } else {
            icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: highlighted ? 1 : 0.8)
        }
    }

    private var hoverExpansion: CGFloat {
        return hoveredDirection == nil ? 0 : 7
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

    private func direction(at point: CGPoint) -> MouseGestureDirection? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= 30 else { return nil }
        let direction: MouseGestureDirection = abs(dx) > abs(dy)
            ? (dx > 0 ? .right : .left)
            : (dy > 0 ? .up : .down)
        return directions.contains(direction) ? direction : nil
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
}
