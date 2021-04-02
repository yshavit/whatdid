// whatdidUITests?

import XCTest

class UITestBase: XCTestCase {
    
    private static var app : XCUIApplication?
    /// A point within the status menu item. Access this via `var statusItemPoint`, which calculates it if needed.
    private static var _statusItemPoint: CGPoint?
    
    var app: XCUIApplication {
        UITestBase.app!
    }
    
    func activate() {
        UITestBase.activate()
    }
    
    static var statusItemPoint: CGPoint {
        get {
            if let result = _statusItemPoint {
                return result
            } else {
                activate()
                // The 0.5 isn't necessary, but it positions the cursor in the middle of the item. Just looks nicer.
                let menuItem = XCUIApplication().menuBars.children(matching: .statusItem).element(boundBy: 0)
                menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
                _statusItemPoint = CGEvent(source: nil)?.location
                return _statusItemPoint!
            }
        }
    }
    
    func clickStatusMenu(with flags: CGEventFlags = []) {
        // In headless mode (or whatever GH actions uses), I can't just use the XCUIElement's `click()`
        // when the app is in the background. Instead, I fetched the status item's location during setUp, and
        // now directly post the click events to it.
        group("Click status menu") {
            leftClick("status menu", at: UITestBase.statusItemPoint, with: flags)
        }
    }
    
    func leftClick(_ description: String, at point: CGPoint, with flags: CGEventFlags = []) {
        group("Click \(description)") {
            for eventType in [CGEventType.leftMouseDown, CGEventType.leftMouseUp] {
                clickEvent(.left, eventType, at: point, with: flags)
            }
        }
    }
    
    func dragStatusMenu(to newX: CGFloat) {
        group("Drag status menu") {
            clickEvent(.left, .leftMouseDown, at: UITestBase.statusItemPoint, with: .maskCommand)
            clickEvent(.left, .leftMouseUp, at: CGPoint(x: newX, y: UITestBase.statusItemPoint.y), with: [])
            let oldPoint = UITestBase.statusItemPoint
            // We dragged to the very edge of the screen, but the actual icon will
            // be to the left of that (for instance, it can't be to the right of the clock).
            // So, just invalidate our statusItemPoint cache, and we'll look it up as needed.
            UITestBase._statusItemPoint = nil
            
            addTeardownBlock {
                self.group("Drag status menu back") {
                    self.clickEvent(.left, .leftMouseDown, at: UITestBase.statusItemPoint, with: .maskCommand)
                    self.clickEvent(.left, .leftMouseUp, at: oldPoint, with: [])
                    UITestBase._statusItemPoint = oldPoint
                }
            }
        }
    }
    
    func launch(withEnv env: [String: String]) {
        UITestBase.launch(withEnv: env)
    }
    
    func uiSetUp() {
        // nothing
    }
    
    final override func setUp() {
        continueAfterFailure = false
        if UITestBase.app == nil {
            UITestBase.launch(withEnv: startupEnv(suppressTutorial: true))
        }

        let now = Date()
        log("Finished setup at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
        uiSetUp()
    }
    
    final override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        XCUIApplication().terminate()
        UITestBase.app = nil
        let now = Date()
        log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
        super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
    }
    
    private static func activate() {
        guard let app = app else {
            NSLog("ERROR: no app to activate")
            return
        }
        app.activate()
        if !app.wait(for: .runningForeground, timeout: 15) {
            log("Timed out waiting to run in foreground. Will try to continue. Current state: \(app.state.rawValue)")
        }
    }
    
    private static func launch(withEnv env: [String: String]) {
        let app = XCUIApplication()
        PtnViewControllerTest.app = app
        app.launchEnvironment = env
        app.launch()
    }
}
