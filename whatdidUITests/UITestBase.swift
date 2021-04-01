// whatdidUITests?

import XCTest

class UITestBase: XCTestCase {
    
    private static var app : XCUIApplication?
    /// A point within the status menu item. See `clickStatusMenu()`
    private static var statusItemPoint: CGPoint!
    
    var app: XCUIApplication {
        UITestBase.app!
    }
    
    var statusItemPoint: CGPoint {
        UITestBase.statusItemPoint
    }
    
    func activate() {
        UITestBase.activate()
    }
    
    func findStatusMenuItem() {
        UITestBase.findStatusMenuItem()
    }
    
    func launch(withEnv env: [String: String]) {
        UITestBase.launch(withEnv: env)
    }
    
    final override func setUp() {
        continueAfterFailure = false
        if UITestBase.app == nil {
            UITestBase.launch(withEnv: startupEnv(suppressTutorial: true))
        }

        let now = Date()
        log("Finished setup at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
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
    
    private static func findStatusMenuItem() {
        activate()
        // The 0.5 isn't necessary, but it positions the cursor in the middle of the item. Just looks nicer.
        let menuItem = XCUIApplication().menuBars.children(matching: .statusItem).element(boundBy: 0)
        menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        UITestBase.statusItemPoint = CGEvent(source: nil)?.location
    }
    
    private static func launch(withEnv env: [String: String]) {
        let app = XCUIApplication()
        PtnViewControllerTest.app = app
        app.launchEnvironment = env
        app.launch()
        findStatusMenuItem()
    }
}
