// whatdid?
#if UI_TEST
import Cocoa

class ManualTickSchedulerWindow: NSObject, NSTextFieldDelegate {
    
    private static let deferCheckboxTitle = "Defer until deactivation"
    /// Note that this is super wide. We'll also set the alpha to 0, which effectively hides the item.
    /// This lets us take screenshots of it without it getting in the way; and the wideness means that if we
    /// order the icons as whatdid's being rightmost and then this directly left of it, then the screenshots won't include
    /// any other icons the system has, either.
    let activatorStatusItem = NSStatusBar.system.statusItem(withLength: 400)
    
    let scheduler: ManualTickScheduler = DefaultScheduler.instance
    private let deferButton: NSButton
    private let setter: NSTextField
    private let printUtc: NSTextField
    private let printLocal: NSTextField
    private let entriesField: NSTextField
    private let pasteboardButton: PasteboardView
    
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
        // We need to init pasteboardButton before super.init(), but we can't set target: self until after that call.
        // So we create most of the field's hookup here, but then set the target below
        entriesField.action = #selector(self.setEntriesViaJson(field:))
        
        // See the comment on entriesField above for why we don't set the action yet
        pasteboardButton = PasteboardView()
        pasteboardButton.setAccessibilityLabel("uihook_flatentryjson_pasteboard")
        
        super.init()
        
        updateDate()
        scheduler.addListener(self.updateDateDisplays(to:))
        setter.delegate = self
        
        entriesField.target = self
        pasteboardButton.action = {data in
            self.setEntriesViaJson(string: data)
            self.entriesField.stringValue = data
        }
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
        adder(pasteboardButton)
        
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
        button.attributedTitle = NSAttributedString(string: button.title, attributes: [
            NSAttributedString.Key.foregroundColor: NSColor.black.withAlphaComponent(0)
        ])
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
    
    @objc private func setEntriesViaJson(field: NSTextField) {
        setEntriesViaJson(string: entriesField.stringValue)
    }
    
    private func setEntriesViaJson(string: String) {
        let entries = FlatEntry.deserialize(from: string)
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
