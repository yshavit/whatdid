// whatdidUITests?

import XCTest

class UITestBase: XCTestCase {
    
    private static var app : XCUIApplication?
    /// Whether we should restart the app at setup, if it's already running
    private static var shouldRestartApp = false
    
    var app: XCUIApplication {
        UITestBase.app!
    }
    
    func activate() {
        UITestBase.activate()
    }
    
    static func hoverToFindPoint(in element: XCUIElement) -> CGPoint {
        // The 0.5 isn't necessary, but it positions the cursor in the middle of the item. Just looks nicer.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        return CGEvent(source: nil)!.location
    }
    
    func clickStatusMenu(with modifiers: XCUIElement.KeyModifierFlags = []) {
        // In headless mode (or whatever GH actions uses), I can't just use the XCUIElement's `click()`
        // when the app is in the background. Instead, I fetched the status item's location during setUp, and
        // now directly post the click events to it.
        group("Click status menu") {
            XCUIElement.perform(withKeyModifiers: modifiers) {
                app.menuBars.children(matching: .statusItem).element(boundBy: 0).click()
            }
        }
    }
    
    func dragStatusMenu(to newX: CGFloat) {
        group("Drag status menu") {
            let menuItem = app.menuBars.children(matching: .statusItem).element(boundBy: 0)
            let originalCoordinate = menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let originalCoordinateAbs = originalCoordinate.screenPoint
            
            let deltaToNewX = newX - originalCoordinateAbs.x
            let newXCoordinate = originalCoordinate.withOffset(CGVector(dx: deltaToNewX, dy: 0))
            
            XCUIElement.perform(withKeyModifiers: .command) {
                originalCoordinate.click(forDuration: 0.25, thenDragTo: newXCoordinate)
            }
            
            addTeardownBlock {
                self.group("Drag status menu back") {
                    let currentCoordinate = menuItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    let currentCoordinateAbs = currentCoordinate.screenPoint
                    let revertCoordinate = currentCoordinate.withOffset(CGVector(
                        dx: originalCoordinateAbs.x - currentCoordinateAbs.x,
                        dy: originalCoordinateAbs.y - currentCoordinateAbs.y)
                    )
                    XCUIElement.perform(withKeyModifiers: .command) {
                        currentCoordinate.click(forDuration: 0.25, thenDragTo: revertCoordinate)
                    }
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
    
    /// A teardown hook. This will be called once per test, regardless of whether the test succeeded or failed. If it happens after a failure,
    /// this will be invoked before the application gets terminated.
    func uiTearDown() {
        // nothing
    }
    
    final override func setUp() {
        continueAfterFailure = false
        if UITestBase.shouldRestartApp {
            if let app = UITestBase.app {
                app.terminate()
                UITestBase.app = nil
            }
            UITestBase.shouldRestartApp = false
        }
        
        if UITestBase.app == nil {
            UITestBase.launch(withEnv: startupEnv(suppressTutorial: true))
        }

        let now = Date()
        log("Finished setup at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
        uiSetUp()
    }
    
    final override func tearDown() {
        if UITestBase.app != nil {
            uiTearDown()
        }
    }
    
    final override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        group("recordFailure") {
            if UITestBase.app != nil {
                uiTearDown()
            } else {
                log("ERROR: couldn't find app, so won't call uiTearDown!")
            }
            UITestBase.shouldRestartApp = true
            let now = Date()
            log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
            super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
        }
    }
    
    private static func activate() {
        guard let app = app else {
            XCTFail("ERROR: no app to activate")
            return
        }
        wait(for: "app to activate") {
            app.activate()
            return app.wait(for: .runningForeground, timeout: 3)
        }
    }
    
    private static func launch(withEnv env: [String: String]) {
        let app = XCUIApplication()
        PtnViewControllerTest.app = app
        app.launchEnvironment = env
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
    }
}
