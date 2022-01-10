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
    
    private static var _uiHookTimeZone: TimeZone?
    
    override func uiSetUp() {
        activate()
        XCUIElement.perform(withKeyModifiers: .option) {
            app.menuBars.statusItems["Focus Whatdid"].click()
        }
        wait(for: "window to close", until: {openWindow == nil})
    }
    
    override func uiTearDown() {
        activate()
        let logs = app.windows["UI Test Window"].textViews["uitestlogstream"].stringValue
        let attachment = XCTAttachment(string: logs)
        attachment.name = "logs for \(self.description)"
        add(attachment)
        
        clearPasteboardIfNeeded()
    }
    
    private var uiHooksWindow: XCUIElement {
        let mockedClockWindow = app.windows["UI Test Window"]
        activate()
        app.menuBars.statusItems["Focus Whatdid"].click()
        mockedClockWindow.staticTexts.firstMatch.click()
        return mockedClockWindow
    }
    
    var uiHookTimeZone: TimeZone {
        if AppUITestBase._uiHookTimeZone == nil {
            let tzId = uiHooksWindow.staticTexts["time_zone_identifier"].stringValue
            AppUITestBase._uiHookTimeZone = TimeZone(identifier: tzId)!
        }
        return AppUITestBase._uiHookTimeZone!
    }
    
    func athensTime(_ year: Int, _ month: Int, _ day: Int, t hour: Int, _ minute: Int, _ second: Int) -> Date {
        return DateComponents(
            calendar: Calendar.current,
            timeZone: uiHookTimeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }
    
    /// Sets the mocked clock in UTC. If `deactivate` is true (default false), then this will set the mocked clock to set the time when the app deactivates, and then this method will activate
    /// the finder. Otherwise, `onSessionPrompt` governs what to do if the "start a new session?" prompt comes up.
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, s: Int = 0, deactivate: Bool = false, activateFirst: Bool = true) {
        group("setting time \(d)d \(h)h \(m)m \(s)s") {
            let epochSeconds = d * 86400 + h * 3600 + m * 60 + s
            let text = "\(epochSeconds)\r"
            let mockedClockWindow = uiHooksWindow
            let clockTicker = mockedClockWindow.textFields["uitestwindowclock"]
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
    
    func longSessionPromptQuery(on window: XCUIElement) -> XCUIElementQuery {
        return window.sheets.matching(NSPredicate(format: "title = %@", "Start new session?"))
    }
    
    func checkThatLongSessionPrompt(on window: XCUIElement, exists: Bool) {
        wait(for: "long session prompt", until: {
            let actual = longSessionPromptQuery(on: window).count
            let expected = exists ? 1 : 0
            return expected == actual
        })
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
    
    var entriesHook: [FlatEntry] {
        get {
            activate()
            app.menuBars.statusItems["Focus Whatdid"].click()
            let field = app.windows["UI Test Window"].textFields["uihook_flatentryjson"]
            return FlatEntry.deserialize(from: field.stringValue)
        }
        set (value) {
            activate()
            clearPasteboardIfNeeded()
            
            let pasteboardButton = app.windows["UI Test Window"].buttons["uihook_flatentryjson_pasteboard"]
            let rmButton = app.windows["UI Test Window"].buttons["uihook_flatentryjson_pasteboard_rm"]
            pasteboardButton.click()
            
            wait(for: "pasteboard to be set up", until: {rmButton.isEnabled})
            let pasteboard = NSPasteboard(name: .init(pasteboardButton.title))
            pasteboard.clearContents()
            let entriesString = FlatEntry.serialize(value)
            XCTAssertTrue(pasteboard.setString(entriesString, forType: .string))
            pasteboardButton.click()
        }
    }
    
    private func clearPasteboardIfNeeded() {
        activate()
        let rmButton = app.windows["UI Test Window"].buttons["uihook_flatentryjson_pasteboard_rm"]
        if rmButton.isEnabled {
            rmButton.click()
        }
        wait(for: "pasteboard to release", until: {!rmButton.isEnabled})
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
    
    var animationFactor: Double {
        get {
            let asString = uiHooksWindow.textFields["uitestanimationfactor"].stringValue
            return Double(asString)!
        }
        set (value) {
            uiHooksWindow.textFields["uitestanimationfactor"].deleteText(andReplaceWith: "\(value)\r")
        }
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
        
        func clickDisclosure(until element: XCUIElement, isVisible expectedVisibility: Bool) {
            XCTContext.runActivity(named: "Click \(disclosure.simpleDescription)") {context in
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
                disclosure.click()
                wait(for: "element to \(expectedVisibility ? "be visible" : "not be visible")") {
                    return element.isVisible == expectedVisibility
                }
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
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
