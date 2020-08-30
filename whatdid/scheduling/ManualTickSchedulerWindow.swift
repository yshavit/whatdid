// whatdid?
#if UI_TEST
import Cocoa

class ManualTickSchedulerWindow: NSObject, NSTextFieldDelegate {
    
    let scheduler: ManualTickScheduler
    private let deferButton: NSButton
    private let setter: NSTextField
    private let printUtc: NSTextField
    private let printLocal: NSTextField
    private let window: NSPanel
    
    init(with scheduler: ManualTickScheduler) {
        self.scheduler = scheduler
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 50, width: 100, height: 50),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered,
            defer: true,
            screen: nil)
        window.title = "Mocked Clock"
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        window.contentView = stack
        
        setter = NSTextField(string: "0")
        setter.isEditable = true
        stack.addArrangedSubview(setter)
        
        deferButton = NSButton(checkboxWithTitle: "Deactivate before setting", target: nil, action: nil)
        stack.addArrangedSubview(deferButton)
        
        printUtc = NSTextField(labelWithString: "")
        stack.addArrangedSubview(printUtc)
        
        printLocal = NSTextField(labelWithString: "")
        stack.addArrangedSubview(printLocal)
        
        super.init()
        updateDate()
        window.setIsVisible(true)
        setter.delegate = self
    }
    
    @objc func setterAction() {
        print(setter.stringValue)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        updateDate()
    }
    
    private func updateDate() {
        if let dateAsInt = Int(setter.stringValue) {
            let date = Date(timeIntervalSince1970: Double(dateAsInt))
            
            let timeFormatter = ISO8601DateFormatter()
            timeFormatter.timeZone = TimeZone(identifier: "UTC")!
            printUtc.stringValue = timeFormatter.string(from: date)
            
            timeFormatter.timeZone = DefaultScheduler.instance.timeZone
            printLocal.stringValue = timeFormatter.string(from: date)
            
            switch deferButton.state {
            case .on:
                deferButton.state = .off
                AppDelegate.instance.onDeactivation {
                    self.scheduler.now = date
                }
                let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                if finderApps.count != 1 {
                    NSLog("Expected exactly one Finder app. Found \(finderApps.count).")
                    finderApps.forEach {app in NSLog("  id: \(app.bundleIdentifier ?? "<?>"), name: \(app.localizedName ?? "<?>")")}
                } else {
                    finderApps[0].activate(options: [])
                }
            case .off:
                scheduler.now = date
            case let x:
                NSLog("Unexpected state: \(x)")
            }
            
        } else {
            printUtc.stringValue = "ERROR"
            printLocal.stringValue = "ERROR"
        }
    }
}
#endif
