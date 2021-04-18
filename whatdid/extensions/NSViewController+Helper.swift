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
            
            let newSession = ButtonWithClosure(label: "Start new session") {_ in
                window.endSheet(sheet, returnCode: .OK)
            }
            optionsStack.addView(newSession, in: .center)
            
            let continueSession = ButtonWithClosure(label: "Continue with current session") {_ in
                window.endSheet(sheet, returnCode: .continue)
            }
            optionsStack.addView(continueSession, in: .center)
            controller.flasher = {
                // TODO change this to flash the buttons
                wdlog(.debug, "refusing to close while long-session prompt is open")
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
