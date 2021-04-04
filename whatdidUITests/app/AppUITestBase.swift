// whatdidUITests?

import XCTest
@testable import whatdid

class AppUITestBase: UITestBase {
    private static let SOME_TIME = Date()
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> Ptn {
        return group("open PTN") {
            switch openWindow {
            case .none:
                clickStatusMenu()
            case let .some(w) where w.title == WindowType.ptn.windowTitle:
                break
            case let .some(w) where WindowType.allCases.map({$0.windowTitle}).contains(w.title):
                clickStatusMenu()
                wait(for: "window to close", until: {openWindow == nil})
                sleepMillis(500)
                clickStatusMenu()
            case let .some(w):
                XCTFail("unexpected window: \(w.title)")
            }
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptn = findPtn()
            afterAction(ptn.window)
            return ptn
        }
    }
    
    func findPtn() -> Ptn {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        return Ptn(
            window: ptn,
            pcombo: AutocompleteFieldHelper(element: ptn.comboBoxes["pcombo"]),
            tcombo: AutocompleteFieldHelper(element: ptn.comboBoxes["tcombo"]))
    }
    
    /// Clicks on the leftmost element of the date picker, to select its "hours" segment. Otherwise, the system can click
    /// on anywhere in it, and might choose e.g. the AM/PM part.
    func clickOnHourSegment(of datePicker: XCUIElement) {
        datePicker.click(using: .frame(xInlay: 1.0/6))
    }
    
    private static var focusMenuItemPoint: CGPoint?
    
    override func uiSetUp() {
        activate()
        let clickPoint: CGPoint
        if let p = AppUITestBase.focusMenuItemPoint {
            clickPoint = p
        } else {
            let focusMenuItem = XCUIApplication().menuBars.children(matching: .statusItem)["Focus Whatdid"]
            focusMenuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
            AppUITestBase.focusMenuItemPoint = CGEvent(source: nil)?.location
            XCTAssertNotNil(AppUITestBase.focusMenuItemPoint)
            clickPoint = AppUITestBase.focusMenuItemPoint!
        }
        leftClick("focus/reset menu item", at: clickPoint, with: .maskAlternate)
        wait(for: "window to close", until: {openWindow == nil})
    }
    
    /// Sets the mocked clock in UTC. If `deactivate` is true (default false), then this will set the mocked clock to set the time when the app deactivates, and then this method will activate
    /// the finder. Otherwise, `onSessionPrompt` governs what to do if the "start a new session?" prompt comes up.
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, s: Int = 0, deactivate: Bool = false, activateFirst: Bool = true) {
        group("setting time \(d)d \(h)h \(m)m \(s)s") {
            let epochSeconds = d * 86400 + h * 3600 + m * 60 + s
            let text = "\(epochSeconds)\r"
            let mockedClockWindow = app.windows["UI Test Window"]
            activate()
            app.menuBars.statusItems["Focus Whatdid"].click()
            mockedClockWindow.click()
            let clockTicker = mockedClockWindow.children(matching: .textField).element
            if deactivate {
                mockedClockWindow.checkBoxes["Defer until deactivation"].click()
            }
            clockTicker.deleteText(andReplaceWith: text)
            log("Setting time to \(Date(timeIntervalSince1970: TimeInterval(epochSeconds)).utcTimestamp)")
            if deactivate {
                group("Activate Finder") {
                    let finder = NSWorkspace.shared.runningApplications.first(where: {$0.bundleIdentifier == "com.apple.finder"})
                    XCTAssertNotNil(finder)
                    XCTAssertTrue(finder!.activate(options: .activateIgnoringOtherApps))
                    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15))
                    print("Pausing to let things settle")
                    sleep(1)
                    print("Okay, continuing.")
                }
            }
        }
    }
    
    func checkThatLongSessionPrompt(on window: XCUIElement, exists: Bool) {
        let actual = window.sheets.matching(NSPredicate(format: "title = %@", "Start new session?")).count
        let expected = exists ? 1 : 0
        XCTAssertEqual(expected, actual)
    }
    
    func handleLongSessionPrompt(on windowType: WindowType, _ action: LongSessionAction) {
        let window = wait(for: windowType)
        checkThatLongSessionPrompt(on: window, exists: true)
        switch action {
        case .continueWithCurrentSession:
            window.sheets.buttons["Continue with current session"].click()
        case .startNewSession:
            window.sheets.buttons["Start new session"].click()
        case .doNothing:
            break // nothing
        }
    }

    func pressHotkeyShortcut(keyCode: CGKeyCode = 7) {
        // 7 == "x"
        for keyDown in [true, false] {
            let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            let keyEvent = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: keyDown)
            keyEvent!.flags = [.maskCommand, .maskShift]
            keyEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
    
    func find(_ windowType: WindowType) -> XCUIElement {
        let w = app.windows[windowType.windowTitle]
        XCTAssertTrue(w.exists)
        return w
    }
    
    /// Simple overload of `find(_:WindowType)` that lets you use the window in a closure, just to keep variable scope tighter.
    func find(_ windowType: WindowType, then action: (XCUIElement) -> Void) {
        let w = find(windowType)
        action(w)
    }
    
    var openWindowInfo: (WindowType, XCUIElement)? {
        for window in app.windows.allElementsBoundByIndex {
            for windowType in WindowType.allCases {
                if window.exists && window.title == windowType.windowTitle {
                    return (windowType, window)
                }
            }
        }
        return nil
    }
    
    var openWindow: XCUIElement? {
        let potentialWindows = app.windows.matching(NSPredicate(format: "title in %@", Set(WindowType.byTitle.keys))).allElementsBoundByIndex
        
        if potentialWindows.isEmpty {
            return nil
        }
        XCTAssertEqual(1, potentialWindows.count)
        return potentialWindows[0]
    }
    
    var openWindowType: WindowType? {
        guard let openWindow = openWindow else {
            return nil
        }
        return WindowType.byTitle[openWindow.title]
    }
    
    func type(into app: XCUIElement, _ entry: FlatEntry) {
        app.comboBoxes["pcombo"].children(matching: .textField).firstMatch.click()
        for text in [entry.project, entry.task, entry.notes ?? ""] {
            app.typeText(text + "\r")
        }
    }
    
    func date(d: Int = 0, h: Int, m: Int) -> Date {
        let epochSeconds = d * 86400 + h * 3600 + m * 60
        return Date(timeIntervalSince1970: TimeInterval(epochSeconds))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?) -> FlatEntry {
        return entry(project, task, notes, from: t(0), to: t(0))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?, from: Date, to: Date) -> FlatEntry {
        return FlatEntry(from: from, to: to, project: project, task: task, notes: notes)
    }
    
    class func t(_ timeDelta: TimeInterval) -> Date {
        return AppUITestBase.SOME_TIME.addingTimeInterval(timeDelta)
    }
    
    func t(_ timeDelta: TimeInterval) -> Date {
        return AppUITestBase.t(timeDelta)
    }
    
    // assertThat(window: .ptn, isVisible: true)
    func assertThat(window: WindowType, isVisible expected: Bool) {
        XCTAssertEqual(expected, isWindowVisible(window))
    }
    
    func waitForTransition(of window: WindowType, toIsVisible expected: Bool) {
        wait(
            for: "\(String(describing: window)) to \(expected ? "exist" : "not exist")",
            until: {self.isWindowVisible(window) == expected })
    }
    
    func wait(for window: WindowType) -> XCUIElement {
        waitForTransition(of: window, toIsVisible: true)
        return find(window)
    }
    
    func checkForAndDismiss(window: WindowType) {
        waitForTransition(of: window, toIsVisible: true)
        clickStatusMenu()
        waitForTransition(of: window, toIsVisible: false)
    }
    
    func isWindowVisible(_ window: WindowType) -> Bool {
        return app.windows.matching(NSPredicate(format: "title = %@", window.windowTitle)).count > 0
    }
    
    struct HierarchicalEntryLevel {
        let ancestor: XCUIElement
        let scope: String
        let label: String
        
        var headerLabel: XCUIElement {
            ancestor.staticTexts["\(scope) \"\(label)\""].firstMatch
        }
        
        var durationLabel: XCUIElement {
            ancestor.staticTexts["\(scope) time for \"\(label)\""].firstMatch
        }
        
        var disclosure: XCUIElement {
            ancestor.disclosureTriangles["\(scope) details toggle for \"\(label)\""]
        }
        
        var indicatorBar: XCUIElement {
            ancestor.progressIndicators["\(scope) activity indicator for \"\(label)\""]
        }
        
        var allElements: [String: XCUIElement] {
            return ["headerText": headerLabel, "durationText": durationLabel, "disclosure": disclosure, "indicator": indicatorBar]
        }
        
        func clickDisclosure(until element: XCUIElement, _ existence: Existence) {
            XCTContext.runActivity(named: "Click \(disclosure.simpleDescription)") {context in
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
                disclosure.click()
                wait(for: "element to \(existence.asVerb)") {
                    switch existence {
                    case .exists:
                        return element.exists
                    case .isVisible:
                        return element.isVisible
                    case .doesNotExist:
                        return !element.exists
                    }
                }
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
            }
        }
    }
    
    enum Existence {
        case exists
        case isVisible
        case doesNotExist
        
        var asVerb: String {
            switch self {
            case .exists:
                return "exist"
            case .isVisible:
                return "be visible"
            case .doesNotExist:
                return "not exist"
            }
        }
    }
    
    enum LongSessionAction {
        case continueWithCurrentSession
        case startNewSession
        case doNothing
    }
    
    struct Ptn {
        let window: XCUIElement
        let pcombo: AutocompleteFieldHelper
        let tcombo: AutocompleteFieldHelper
        
        var nfield: XCUIElement {
            window.textFields["nfield"]
        }
        
        var entriesHook: XCUIElement {
            window.textFields["uihook_flatentryjson"]
        }
    }
    
    enum WindowType: CaseIterable {
        case ptn
        case dailyEnd
        case morningGoals
        
        var windowTitle: String {
            switch self {
            case .ptn:
                return "What are you working on?"
            case .dailyEnd:
                return "Here's what you've been doing"
            case .morningGoals:
                return "Start the day with some goals"
            }
        }
        
        static var byTitle = WindowType.allCases.reduce(into: [String:WindowType]()) {dict, windowType in
            dict[windowType.windowTitle] = windowType
        }
    }
}
