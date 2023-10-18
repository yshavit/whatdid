// whatdidUITests?

import XCTest
@testable import Whatdid

class LongSessionPromptTest: AppUITestBase {
    func testWhilePtnIsOpen() {
        group("right before long-session promt") {
            clickStatusMenu()
            setTimeUtc(d: 0, h: 5, m: 59)
        }
        group("expect long session prompt") {
            setTimeUtc(d: 0, h: 6, m: 00)
            handleLongSessionPrompt(on: .ptn, .doNothing)
        }
    }
    
    /// compare to `testWhilePtnIsOpen`, which starts the same but does not do the close-and-reopen bits
    func testClosingPtnResetsTheClock() {
        group("right before long-session promt") {
            clickStatusMenu()
            setTimeUtc(d: 0, h: 5, m: 59)
        }
        group("close and re-open PTN") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
        }
        group("expect long session prompt") {
            setTimeUtc(d: 0, h: 6, m: 00)
            sleep(1) // give the sheet time to pop up
            XCTAssertEqual(0, find(.ptn).sheets.allElementsBoundByIndex.count)
        }
    }
    
    func testContinueWithCurrentSession() {
        checkSessionReset(
            onPrompt: {
                handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
            },
            expectDateFrom: date(h: 0, m: 00),
            to: date(h: 6, m: 00))
    }
    
    func testStartNewSession() {
        checkSessionReset(
            onPrompt: {
                handleLongSessionPrompt(on: .ptn, .startNewSession)
                waitForTransition(of: .ptn, toIsVisible: false)
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
            },
            expectDateFrom: date(h: 6, m: 00),
            to: date(h: 6, m: 00))
    }
    
    func testDismissingWindowRetainsQuestion() {
        checkSessionReset(
            onPrompt: {
                group("try to dismiss via click") {
                    clickStatusMenu()
                    sleepMillis(1000) // give the PTN time to go away, if it was going to (it shouldn't)
                    XCTAssertEqual(.ptn, openWindowType)
                }
                group("dismiss prompt") {
                    handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
                }
            },
            expectDateFrom: date(h: 0, m: 00),
            to: date(h: 6, m: 00))
    }
    
    func testLongSessionPromptWithDailyReportUp() {
        group("get to immediately before daily report") {
            setTimeUtc(h: 15, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            checkForAndDismiss(window: .morningGoals) // since we crossed 9am
            setTimeUtc(h: 16, m: 00)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        group("wait 6 hours") {
            setTimeUtc(h: 22, m: 00)
            // we should not have a prompt yet
            sleep(1)
            checkThatLongSessionPrompt(on: find(.dailyEnd), exists: false)
        }
        group("close the daily report") {
            clickStatusMenu()
            waitForTransition(of: .dailyEnd, toIsVisible: false)
        }
        group("ptn pops up with sheet") {
            waitForTransition(of: .ptn, toIsVisible: true)
            checkThatLongSessionPrompt(on: find(.ptn), exists: true)
        }
    }
    
    func testLongSessionPromptWithMorningGoals() {
        group("get to immediately before morning goals") {
            setTimeUtc(h: 6, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            waitForTransition(of: .dailyEnd, toIsVisible: false)
        }
        group("get to morning prompt") {
            setTimeUtc(h: 7, m: 00)
            waitForTransition(of: .morningGoals, toIsVisible: true)
        }
        group("wait 6 hours") {
            setTimeUtc(h: 13)
            checkThatLongSessionPrompt(on: find(.morningGoals), exists: true)
        }
    }
    
    private func checkSessionReset(onPrompt: () -> Void, expectDateFrom start: Date, to end: Date) {
        group("bring up long session prompt") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            setTimeUtc(h: 6)
        }
        group("handle session") {
            onPrompt()
        }
        group("type an entry") {
            let ptn = findPtn()
            type(into: ptn.window, entry("pA", "tB", "nC"))
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("validate") {
            XCTAssertEqual(
                [FlatEntry(from: start, to: end, project: "pA", task: "tB", notes: "nC")],
                entriesHook)
        }
    }
}
