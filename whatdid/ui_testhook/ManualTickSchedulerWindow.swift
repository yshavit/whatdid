// whatdid?
#if UI_TEST
import Cocoa

class ManualTickSchedulerWindow: NSObject, NSTextFieldDelegate {
    
    private static let deferCheckboxTitle = "Defer until deactivation"
    let activatorStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let scheduler: ManualTickScheduler = DefaultScheduler.instance
    private let deferButton: NSButton
    private let setter: NSTextField
    private let printUtc: NSTextField
    private let printLocal: NSTextField
    private let entriesField: NSTextField
    
    override init() {
        setter = NSTextField(string: "0")
        setter.isEditable = true
        setter.setAccessibilityLabel("uitestwindowclock")
        
        deferButton = NSButton(checkboxWithTitle: ManualTickSchedulerWindow.deferCheckboxTitle, target: nil, action: nil)
        
        printUtc = NSTextField(labelWithString: "")
        printUtc.setAccessibilityLabel("mockclock_status")
        printLocal = NSTextField(labelWithString: "")
        
        entriesField = NSTextField(string: "")
        entriesField.setAccessibilityLabel("uihook_flatentryjson")
        entriesField.action = #selector(setEntriesViaJson)
        
        super.init()
        
        updateDate()
        scheduler.addListener(self.updateDateDisplays(to:))
        setter.delegate = self
        
        entriesField.target = self
        entriesField.action = #selector(self.setEntriesViaJson(_:))
        AppDelegate.instance.model.addListener(self.populateJsonFlatEntryField)
        
        setUpActivator()
    }
    
    func build(adder: @escaping (NSView) -> Void) {
        adder(setter)
        adder(deferButton)
        adder(printUtc)
        adder(printLocal)
        
        let div1 = NSBox()
        div1.boxType = .separator
        adder(div1)
        adder(entriesField)
        
        let div2 = NSBox()
        div2.boxType = .separator
        adder(div2)
        adder(ButtonWithClosure(label: "Reset All", {_ in AppDelegate.instance.resetAll()}))
    }
    
    private func setUpActivator() {
        guard let button = activatorStatusItem.button else {
            fatalError("No activator button")
        }
        button.title = "Focus Whatdid"
        button.target = self
        button.action = #selector(grabFocus)
    }
    
    @objc private func grabFocus() {
        if NSEvent.modifierFlags.contains(.option) {
            AppDelegate.instance.resetAll()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = setter.window {
            window.makeKeyAndOrderFront(self)
            window.makeFirstResponder(setter)
        }
    }
    
    func populateJsonFlatEntryField() {
        let entries = AppDelegate.instance.model.listEntries(since: Date.distantPast)
        entriesField.stringValue = FlatEntry.serialize(entries)
    }
    
    @objc private func setEntriesViaJson(_ field: NSTextField) {
        let entries = FlatEntry.deserialize(from: entriesField.stringValue)
        AppDelegate.instance.resetModel()
        entries.forEach {AppDelegate.instance.model.add($0, andThen: {})}
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        updateDate()
    }
    
    func updateDateDisplays(to date: Date) {
        setter.stringValue = "\(Int(date.timeIntervalSince1970))"
        
        let timeFormatter = ISO8601DateFormatter()
        timeFormatter.timeZone = TimeZone.utc
        printUtc.stringValue = timeFormatter.string(from: date)
        
        timeFormatter.timeZone = DefaultScheduler.instance.timeZone
        printLocal.stringValue = timeFormatter.string(from: date)
    }
    
    private func updateDate() {
        if let dateAsInt = Int(setter.stringValue) {
            let date = Date(timeIntervalSince1970: Double(dateAsInt))
            updateDateDisplays(to: date)
            
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
