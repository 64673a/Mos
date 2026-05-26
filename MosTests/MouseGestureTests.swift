import XCTest
@testable import Mos_Debug

final class MouseGestureTests: XCTestCase {

    private func mouseTrigger(code: UInt16 = 3) -> RecordedEvent {
        return RecordedEvent(type: .mouse, code: code, modifiers: 0, displayComponents: ["Mouse"], deviceFilter: nil)
    }

    func testMouseGestureOptionsRequiresTriggerAndAtLeastOneAction() {
        var config = MouseGestureOptions()
        XCTAssertFalse(config.isEnabled)

        config.triggerEvent = mouseTrigger()
        XCTAssertFalse(config.isEnabled)

        config.directions[.up] = MouseGestureAction(systemShortcutName: "copy")
        XCTAssertTrue(config.isEnabled)
    }

    func testMouseGestureOptionsRejectsKeyboardTrigger() {
        let trigger = RecordedEvent(type: .keyboard, code: 8, modifiers: 0, displayComponents: ["C"], deviceFilter: nil)
        let config = MouseGestureOptions(
            triggerEvent: trigger,
            directions: [.up: MouseGestureAction(systemShortcutName: "copy")]
        )

        XCTAssertFalse(config.isEnabled)
    }

    func testMouseGestureOptionsRejectsMainMouseButtonsAsTrigger() {
        for code in KeyCode.mouseMainKeys {
            let config = MouseGestureOptions(
                triggerEvent: mouseTrigger(code: code),
                directions: [.up: MouseGestureAction(systemShortcutName: "copy")]
            )
            XCTAssertFalse(config.isEnabled)
        }
    }

    func testHitTesterUsesActivationDistanceAndEnabledDirections() {
        let tester = MouseGestureHitTester(
            center: CGPoint(x: 100, y: 100),
            enabledDirections: [.up, .right]
        )

        XCTAssertNil(tester.direction(at: CGPoint(x: 100, y: 116)))
        XCTAssertEqual(tester.direction(at: CGPoint(x: 100, y: 122)), .up)
        XCTAssertEqual(tester.direction(at: CGPoint(x: 100, y: 150)), .up)
        XCTAssertEqual(tester.direction(at: CGPoint(x: 150, y: 100)), .right)
        XCTAssertNil(tester.direction(at: CGPoint(x: 50, y: 100)))
    }

    func testDecodeMouseGestureIgnoresUnknownDirectionAndPreservesUnknownTopLevelField() {
        let json = """
        {
          "triggerEvent": {"type":"mouse","code":3,"modifiers":0,"deviceFilter":null},
          "directions": {
            "up": {"systemShortcutName":"copy","openTarget":null},
            "diagonal": {"systemShortcutName":"paste","openTarget":null}
          },
          "futureField": {"enabled": true}
        }
        """
        let result = Options.decodeMouseGestureWithUnknownFields(from: json.data(using: .utf8)!)

        XCTAssertEqual(result.config?.triggerEvent?.code, 3)
        XCTAssertEqual(result.config?.directions[.up]?.systemShortcutName, "copy")
        XCTAssertNil(result.config?.directions[.left])
        XCTAssertEqual(result.unknownFields.count, 1)
    }

    func testDecodeMouseGestureWithInconsistentOpenTargetDisablesKnownConfigButPreservesUnknownFields() {
        let json = """
        {
          "triggerEvent": {"type":"mouse","code":3,"modifiers":0,"deviceFilter":null},
          "directions": {
            "up": {"systemShortcutName":"openTarget","openTarget":null}
          },
          "futureField": {"enabled": true}
        }
        """
        let result = Options.decodeMouseGestureWithUnknownFields(from: json.data(using: .utf8)!)

        XCTAssertNil(result.config)
        XCTAssertEqual(result.unknownFields.count, 1)
    }

    func testMouseGestureActionRejectsStatefulAction() {
        XCTAssertTrue(MouseGestureAction(systemShortcutName: "copy").isTriggerAction)
        XCTAssertFalse(MouseGestureAction(systemShortcutName: "mouseLeftClick").isTriggerAction)
        XCTAssertFalse(MouseGestureAction(systemShortcutName: "modifierShift").isTriggerAction)
    }
}
