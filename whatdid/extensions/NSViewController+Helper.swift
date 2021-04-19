// whatdid?

import Cocoa

extension NSViewController {
    private static let TIME_UNTIL_NEW_SESSION_PROMPT = TimeInterval(6 * 60 * 60)
    
    /// Closes the window that this controller is in. This happens from a `DispatchQueue.main.async` call, which
    /// you need in order for things to work right (I forget what, exactly).
    func closeWindowAsync() {
        DispatchQueue.main.async {
            self.view.window?.windowController?.close()
        }
    }
    
    func setUpNewSessionPrompt(scheduler: Scheduler, onNewSession: @escaping Action, onKeepSesion: @escaping Action) {
        if scheduler.timeInterval(since: AppDelegate.instance.model.lastEntryDate) > NSViewController.TIME_UNTIL_NEW_SESSION_PROMPT {
            showNewSessionPrompt(onNewSession: onNewSession, onKeepSesion: onKeepSesion)
        } else {
            scheduler.schedule(
                "new session prompt",
                after: NSViewController.TIME_UNTIL_NEW_SESSION_PROMPT,
                {
                    self.showNewSessionPrompt(onNewSession: onNewSession, onKeepSesion: onKeepSesion)
                })
        }
    }
    
    private func showNewSessionPrompt(onNewSession: @escaping () -> Void, onKeepSesion: @escaping () -> Void) {
        if let window = view.window {
            let sheet = NSWindow(contentRect: window.contentView!.frame, styleMask: [], backing: .buffered, defer: true)
            sheet.setAccessibilityTitle("Start new session?")
            let mainStack = NSStackView()
            mainStack.orientation = .vertical
            mainStack.useAutoLayout()
            mainStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            
            let controller = RefuseToCloseController()
            controller.view = mainStack
            sheet.contentViewController = controller
            mainStack.widthAnchor.constraint(equalToConstant: window.frame.width).isActive = true
            mainStack.heightAnchor.constraint(greaterThanOrEqualToConstant: window.frame.height).isActive = true
            
            let headerLabel = NSTextField(labelWithString: "It's been a while since you last checked in.")
            headerLabel.font = NSFont.boldSystemFont(ofSize: NSFont.labelFontSize * 1.25)
            mainStack.addArrangedSubview(headerLabel)
            
            let optionsStack = NSStackView()
            optionsStack.useAutoLayout()
            mainStack.addArrangedSubview(optionsStack)
            optionsStack.orientation = .horizontal
            optionsStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
            
            let newSessionButton = ButtonWithClosure(label: "Start new session") {_ in
                window.endSheet(sheet, returnCode: .OK)
            }
            optionsStack.addView(newSessionButton, in: .center)
            
            let continueSessionButton = ButtonWithClosure(label: "Continue with current session") {_ in
                window.endSheet(sheet, returnCode: .continue)
            }
            optionsStack.addView(continueSessionButton, in: .center)
            controller.flasher = {
                wdlog(.debug, "refusing to close while long-session prompt is open")
                flash(continueSessionButton)
                flash(newSessionButton)
            }
            
            window.makeFirstResponder(nil)
            window.beginSheet(sheet) {response in
                let startNewSession: Bool
                switch(response) {
                case .OK:
                    wdlog(.debug, "Starting new session")
                    startNewSession = true
                case .continue:
                    wdlog(.debug, "Continuing with existing session")
                    startNewSession = false
                case .abort:
                    wdlog(.debug, "Aborting window (probably because user closed it via status menu item)")
                    startNewSession = false
                default:
                    wdlog(.warn, "Unexpected response: %@. Will start new session session.", response.rawValue)
                    startNewSession = false
                }
                if startNewSession {
                    AppDelegate.instance.model.setLastEntryDateToNow()
                    onNewSession()
                } else {
                    onKeepSesion()
                }
            }
        }
    }
}

fileprivate class RefuseToCloseController: NSViewController, CloseConfirmer {
    
    var flasher = {}
    
    func requestClose(on: NSWindow) -> Bool {
        flasher()
        return false
    }
}

fileprivate func flash(_ button: NSButton, flashDuration: TimeInterval = 0.12, count: Int = 2) {
    let originalTitle = button.attributedTitle
    let highlightedTitle = NSMutableAttributedString(attributedString: originalTitle)
    highlightedTitle.addAttribute(
        .foregroundColor,
        value: NSColor.controlAccentColor,
        range: NSRange(location: 0, length: highlightedTitle.length))
    
    // Even in ui-test mode, we want to flash in realtime.
    // We can't test the colors in a UI test, so we may as well get a visual that looks okay
    // without being cumbersome.
    let scheduler = SystemClockScheduler()
    
    func oneFlash(remaining: Int) {
        if remaining > 0 {
            button.attributedTitle = highlightedTitle
            scheduler.schedule("flash #\(remaining)", after: flashDuration) {
                button.attributedTitle = originalTitle
                let nextRemaining = remaining - 1
                if nextRemaining > 0 {
                    scheduler.schedule("next flash", after: flashDuration) {
                        oneFlash(remaining: nextRemaining)
                    }
                }
            }
        }
    }
    oneFlash(remaining: count)
    
}
