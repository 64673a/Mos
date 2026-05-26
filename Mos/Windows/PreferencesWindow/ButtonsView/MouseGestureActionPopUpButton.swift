//
//  MouseGestureActionPopUpButton.swift
//  Mos
//

import Cocoa

final class MouseGestureActionPopUpButton: NSPopUpButton, NSMenuDelegate, KeyRecorderDelegate {
    var onChange: ((MouseGestureAction?) -> Void)?
    var onOpenTargetSelectionRequested: (() -> Void)?

    private let actionDisplayResolver = ActionDisplayResolver()
    private let actionDisplayRenderer = ActionDisplayRenderer()
    private var currentAction: MouseGestureAction?
    private var isCustomRecordingActive = false
    private lazy var customRecorder: KeyRecorder = {
        let recorder = KeyRecorder()
        recorder.delegate = self
        return recorder
    }()

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        setupMenu()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMenu()
    }

    func configure(action: MouseGestureAction?, showLogiActions: Bool) {
        currentAction = action?.isBound == true ? action : nil
        setupMenu(showLogiActions: showLogiActions)
        refreshActionDisplay()
    }

    private func setupMenu(showLogiActions: Bool = false) {
        let menu = NSMenu()
        menu.delegate = self
        ShortcutManager.buildShortcutMenu(
            into: menu,
            target: self,
            action: #selector(shortcutSelected(_:)),
            showLogiActions: showLogiActions,
            allowedExecutionModes: [.trigger]
        )
        disableKeyEquivalents(in: menu)
        self.menu = menu
        refreshActionDisplay()
    }

    private var actionState: CellActionState {
        if isCustomRecordingActive { return .recordingPrompt }
        guard let action = currentAction else { return .unbound }
        if let openTarget = action.openTarget {
            return .openTarget(openTarget)
        }
        if let shortcut = SystemShortcut.getShortcut(named: action.systemShortcutName) {
            return .namedShortcut(shortcut)
        }
        if action.systemShortcutName.hasPrefix("custom::") {
            return .customBinding(name: action.systemShortcutName)
        }
        return .unbound
    }

    private func refreshActionDisplay() {
        let presentation = actionDisplayResolver.resolve(state: actionState)
        actionDisplayRenderer.render(presentation, into: self)
    }

    @objc private func shortcutSelected(_ sender: NSMenuItem) {
        if sender.representedObject as? String == "__open__" {
            refreshActionDisplay()
            onOpenTargetSelectionRequested?()
            return
        }

        if sender.representedObject as? String == "__custom__" {
            isCustomRecordingActive = true
            refreshActionDisplay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self, self.window != nil else { return }
                self.customRecorder.startRecording(from: self, mode: .adaptive)
            }
            return
        }

        guard let shortcut = sender.representedObject as? SystemShortcut.Shortcut else {
            currentAction = nil
            onChange?(nil)
            refreshActionDisplay()
            return
        }

        currentAction = MouseGestureAction(systemShortcutName: shortcut.identifier)
        onChange?(currentAction)
        refreshActionDisplay()
    }

    func updateOpenTarget(_ payload: OpenTargetPayload) {
        currentAction = MouseGestureAction(openTarget: payload)
        onChange?(currentAction)
        refreshActionDisplay()
    }

    func menuWillOpen(_ menu: NSMenu) {
        adjustMenuStructure(menu)
        enableKeyEquivalents(in: menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        disableKeyEquivalents(in: menu)
    }

    private func adjustMenuStructure(_ menu: NSMenu) {
        guard menu.items.count >= 3 else { return }
        let placeholderItem = menu.items[0]
        let firstSeparator = menu.items[1]
        let unboundItem = menu.items[2]
        if actionState.hasBoundAction {
            placeholderItem.isHidden = false
            firstSeparator.isHidden = false
            unboundItem.title = NSLocalizedString("unbind", comment: "")
        } else {
            placeholderItem.isHidden = true
            firstSeparator.isHidden = true
            unboundItem.title = NSLocalizedString("unbound", comment: "")
        }
    }

    private func enableKeyEquivalents(in menu: NSMenu) {
        for item in menu.items {
            if let shortcut = item.representedObject as? SystemShortcut.Shortcut {
                let keyEquivalent = shortcut.keyEquivalent
                item.keyEquivalent = keyEquivalent.keyEquivalent
                item.keyEquivalentModifierMask = keyEquivalent.modifierMask
            }
            if let submenu = item.submenu {
                enableKeyEquivalents(in: submenu)
            }
        }
    }

    private func disableKeyEquivalents(in menu: NSMenu) {
        for item in menu.items {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            if let submenu = item.submenu {
                disableKeyEquivalents(in: submenu)
            }
        }
    }

    func onRecordingStopped(_ recorder: KeyRecorder, didRecord: Bool) {
        isCustomRecordingActive = false
        guard !didRecord else { return }
        refreshActionDisplay()
    }

    func onEventRecorded(_ recorder: KeyRecorder, didRecordEvent event: InputEvent, isDuplicate: Bool) {
        let customName = ButtonBinding.normalizedCustomBindingName(from: event)
        let actionName = SystemShortcut.displayShortcut(matchingBindingName: customName)?.identifier ?? customName
        let action = MouseGestureAction(systemShortcutName: actionName)
        guard action.isTriggerAction else {
            isCustomRecordingActive = false
            refreshActionDisplay()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + KeyRecorder.recordingFeedbackDelay(isDuplicate: false)) { [weak self] in
            guard let self = self else { return }
            self.isCustomRecordingActive = false
            self.currentAction = action
            self.onChange?(action)
            self.refreshActionDisplay()
        }
    }
}
