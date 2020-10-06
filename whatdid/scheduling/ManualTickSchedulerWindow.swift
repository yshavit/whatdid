// whatdid?
#if UI_TEST
import Cocoa

class ManualTickSchedulerWindow: NSObject, NSTextFieldDelegate {
    
    private static let deferCheckboxTitle = "Defer until deactivation"
    let activatorStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let scheduler: ManualTickScheduler
    private let deferButton: NSButton
    private let setter: NSTextField
    private let printUtc: NSTextField
    private let printLocal: NSTextField
    private let window: NSWindow
    
    init(with scheduler: ManualTickScheduler) {
        self.scheduler = scheduler
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 50, width: 100, height: 50),
            styleMask: [.titled],
            backing: .buffered,
            defer: true,
            screen: nil)
        window.level = .floating
        window.title = "Mocked Clock"
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        window.contentView = stack
        
        setter = NSTextField(string: "0")
        setter.isEditable = true
        stack.addArrangedSubview(setter)
        
        deferButton = NSButton(checkboxWithTitle: ManualTickSchedulerWindow.deferCheckboxTitle, target: nil, action: nil)
        stack.addArrangedSubview(deferButton)
        
        printUtc = NSTextField(labelWithString: "")
        printUtc.setAccessibilityLabel("mockclock_status")
        stack.addArrangedSubview(printUtc)
        
        printLocal = NSTextField(labelWithString: "")
        stack.addArrangedSubview(printLocal)
        
        super.init()
        updateDate()
        window.setIsVisible(true)
        setter.delegate = self
        
        setUpActivator()
    }
    
    private func setUpActivator() {
        guard let button = activatorStatusItem.button else {
            fatalError("No activator button")
        }
        button.title = "Focus Mocked Clock"
        button.target = self
        button.action = #selector(grabFocus)
    }
    
    @objc private func grabFocus() {
        window.makeKeyAndOrderFront(self)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        updateDate()
    }
    
    private func updateDate() {
        if let dateAsInt = Int(setter.stringValue) {
            let date = Date(timeIntervalSince1970: Double(dateAsInt))
            
            let timeFormatter = ISO8601DateFormatter()
            timeFormatter.timeZone = TimeZone.utc
            printUtc.stringValue = timeFormatter.string(from: date)
            
            timeFormatter.timeZone = DefaultScheduler.instance.timeZone
            printLocal.stringValue = timeFormatter.string(from: date)
            
            switch deferButton.state {
            case .on:
                deferButton.title = "Deferral pending"
                deferButton.isEnabled = false
                AppDelegate.instance.onDeactivation {
                    self.deferButton.title = ManualTickSchedulerWindow.deferCheckboxTitle
                    self.deferButton.isEnabled = true
                    self.deferButton.state = .off
                    self.scheduler.now = date
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
