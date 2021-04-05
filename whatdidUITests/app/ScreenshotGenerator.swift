// whatdidUITests?
import XCTest
@testable import whatdid

class ScreenshotGenerator: AppUITestBase {

    func testPtnAndDailyReport() {
        group("set up entries") {
            entriesHook = readEntries()
            let lastEntry = entriesHook.last!
            setTimeUtc(s: Int(lastEntry.to.timeIntervalSince1970))
            // PTN will come up
            handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
        }
        
        group("ptn") {
            let ptn = find(.ptn)
            ptn.typeKey(.escape) // dismiss the autocomplete popup
            group("add some goals") {
                let goalsPane = find(.ptn).children(matching: .group).matching(identifier: "Goals for today").firstMatch
                func addGoal(_ text: String, complete: Bool) {
                    goalsPane.buttons["Add new goal"].click()
                    wait(for: "goal field", until: {goalsPane.textFields.count > 0})
                    goalsPane.typeText(text + "\r")
                    wait(for: "goal field", until: {goalsPane.textFields.count == 0})
                    if complete {
                        let newGoal = goalsPane.checkBoxes.allElementsBoundByIndex.last
                        newGoal?.click()
                    }
                }
                addGoal("finish homepage", complete: true)
                addGoal("new UI widget", complete: false)
                addGoal("set up automated tests", complete: true)
            }
            group("start typing an entry") {
                let ptnHelper = findPtn()
                ptnHelper.pcombo.textField.click()
                app.typeText("test\t")
                app.typeText("desig") // incomplete
                screenshot(named: "ptn autocomplete", of: ptn)
            }
            checkForAndDismiss(window: .ptn)
        }
        group("daily report") {
            // The daily report will come up next
            let report = wait(for: .dailyEnd)
            let testInfraTasks = report.groups["Tasks for \"test infrastructure\""]
            group("expand 'test infrastructure' project") {
                let testInfraProject = HierarchicalEntryLevel(ancestor: report, scope: "Project", label: "test infrastructure")
                testInfraProject.clickDisclosure(until: testInfraTasks, .isVisible)
            }
            group("expand details for design doc task") {
                let designDocTask = HierarchicalEntryLevel(ancestor: report, scope: "Task", label: "design doc")
                designDocTask.clickDisclosure(until: testInfraTasks.groups["Details for design doc"], .isVisible)
            }
            screenshot(named: "daily report", of: report)
        }
    }
    
    func screenshot(named name: String, of element: XCUIElement) {
        let frame = element.frame
        let withMenuBar = NSRect(
            x: frame.minX,
            y: 0,
            width: frame.width,
            height: frame.height + frame.minY)
        screenshot(named: "daily report", frame: withMenuBar)
    }
    
    func screenshot(named name: String, frame: NSRect) {
        let screenshot = app.screenshot()
        let sourceFrame: NSRect
        if let scalingFactor = NSScreen.main?.backingScaleFactor {
            // screenshot.image is the whole screen, but scaled. So, divide it by scalingFactor
            // to get the unscaled size (which is what the incoming frame uses).
            // Then, we want the bottom y, on the coordinate system where 0 is the bottom of
            // the screen. The frame coordinate counts from 0 being the top of the screen,
            // including the menu bar.
            let unscaledHeight = (screenshot.image.size.height / scalingFactor)
            let bottomY = unscaledHeight - frame.maxY
            sourceFrame = NSRect(
                x: frame.minX * scalingFactor,
                y: bottomY * scalingFactor,
                width: frame.width * scalingFactor,
                height: frame.height * scalingFactor)
        } else {
            // If we can't get the scaling factor, just get the whole thing; we can edit in post.
            sourceFrame = NSRect(origin: .zero, size: screenshot.image.size)
        }

        let cropped = NSImage(size: sourceFrame.size)
        cropped.lockFocus()
        screenshot.image.draw(at: .zero, from: sourceFrame, operation: .copy, fraction: 1.0)
        cropped.unlockFocus()
        
        NSLog("taking screenshot")
        let attachment = XCTAttachment(image: cropped)
        attachment.lifetime = .keepAlways
        attachment.name = name.replacingOccurrences(of: " ", with: "-")
        add(attachment)
    }
    
    func readEntries() -> [FlatEntry] {
        let realNow = Date() // note! Unlike most of the UI test dates, this is actual, real, wall-clock-now.
        let cal = Calendar.current
        let lastMidnight = cal.date(bySettingHour: 00, minute: 00, second: 00, of: realNow)!
        var lastEntryEnd: Date? = nil
        
        var entries = [FlatEntry]()
        for line in readEntriesFile().split(separator: "\n") {
            /// The format is a backslash delimited line::
            /// ```
            /// | hh:mm | project | task | notes |`
            /// ```
            /// Note that the `hh:mm` is _not_ tab-delimited; that uses a colon, so that it reads nicely.
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            let segments = trimmed.split(separator: "|").map({$0.trimmingCharacters(in: .whitespaces)})
            let hhmm = segments[0].split(separator: ":")
            let project = segments[1]
            let task = segments.maybe(2) ?? ""
            let notes = segments.maybe(3) ?? ""
            
            if hhmm.count != 2 {
                XCTAssertEqual(2, hhmm.count, String(line))
            }
            
            let hours = Int(hhmm[0])!
            let mins = Int(hhmm[1])!
            
            let endDate = cal.date(bySettingHour: hours, minute: mins, second: 0, of: lastMidnight)!
            let startDate = lastEntryEnd ?? endDate.addingTimeInterval(-300)
            entries.append(
                FlatEntry(
                    from: startDate,
                    to: endDate,
                    project: String(project),
                    task: String(task),
                    notes: String(notes)))
            lastEntryEnd = endDate
        }
        print(entries.count)
        return entries
    }
    
    func readEntriesFile() -> String {
        let bundle = Bundle(for: Swift.type(of: self))
        guard let path = bundle.path(forResource: "screenshot-entries", ofType: "txt") else {
            return failAndReturn(with: "couldn't find resource")
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return failAndReturn(with: "no data in resource")
        }
        guard let string = String(data: data, encoding: .utf8) else {
            return failAndReturn(with: "invalid data in resource")
        }
        return string
    }
    
    func failAndReturn<T>(with message: String) -> T {
        let maybe: T? = nil
        XCTFail(message)
        return maybe!
    }
}

private extension Array {
    func maybe(_ index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        return self[index]
    }
}
