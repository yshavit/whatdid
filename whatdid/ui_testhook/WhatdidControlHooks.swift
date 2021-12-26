// whatdid?
#if UI_TEST
import Cocoa

class WhatdidControlHooks: NSObject, NSTextFieldDelegate {
    
    private static let deferCheckboxTitle = "Defer until deactivation"
    private static let showUiConstraintsPrefsKey = "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"
    /// Note that this is super wide. We'll also set the alpha to 0, which effectively hides the item.
    /// This lets us take screenshots of it without it getting in the way; and the wideness means that if we
    /// order the icons as whatdid's being rightmost and then this directly left of it, then the screenshots won't include
    /// any other icons the system has, either.
    let activatorStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let scheduler: ManualTickScheduler = DefaultScheduler.instance
    private let deferButton: NSButton
    private let setter: NSTextField
    private let printUtc: NSTextField
    private let printLocal: NSTextField
    private let entriesField: NSTextField
    private let pasteboardButton: PasteboardView
    private let hideStatusItem: NSButton
    private let showConstraints: NSButton
    
    override init() {
        setter = NSTextField(string: "0")
        setter.isEditable = true
        setter.setAccessibilityLabel("uitestwindowclock")
        
        deferButton = NSButton(checkboxWithTitle: WhatdidControlHooks.deferCheckboxTitle, target: nil, action: nil)
        
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
        
        // See comment on entriesField for why we can't set the target yet
        hideStatusItem = NSButton(checkboxWithTitle: "Hide 'Focus Whatdid' Status Item", target: nil, action: nil)
        
        showConstraints = NSButton(checkboxWithTitle: "Show UI constraints", target: nil, action: nil)
        showConstraints.state = UserDefaults.standard.bool(forKey: WhatdidControlHooks.showUiConstraintsPrefsKey) ? .on : .off
        
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
        
        hideStatusItem.target = self
        hideStatusItem.action = #selector(self.toggleStatusItemVisibility(_:))
        
        showConstraints.target = self
        showConstraints.action = #selector(self.toggleShowUiConstraints(_:))
        
        setUpActivator()
    }
    
    func build(adder: @escaping (NSView) -> Void) {
        func divider() {
            let div = NSBox()
            div.boxType = .separator
            adder(div)
        }
        
        adder(setter)
        adder(deferButton)
        adder(printUtc)
        adder(printLocal)
        
        divider()
        adder(entriesField)
        adder(pasteboardButton)
        
        divider()
        adder(ButtonWithClosure(label: "Reset All", {_ in AppDelegate.instance.resetAll()}))

        divider()
        adder(hideStatusItem)
        
        let animationFactorStack = NSStackView(orientation: .horizontal)
        let animationFactorField = NSTextField(string: AnimationHelper.animation_factor.description)
        animationFactorField.target = self
        animationFactorField.action = #selector(self.setAnimationFactor(_:))
        (animationFactorField.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true
        animationFactorField.setAccessibilityLabel("uitestanimationfactor")
        animationFactorStack.addArrangedSubview(NSTextField(labelWithString: "Animation factor"))
        animationFactorStack.addArrangedSubview(animationFactorField)
        adder(animationFactorStack)
        adder(showConstraints)
        
        divider()
        adder(NSTextField(labelWithString: "Log messages:"))
        let logFieldScroller = NSTextView.scrollableTextView()
        adder(logFieldScroller)
        let logField = logFieldScroller.documentView as! NSTextView
        logField.setAccessibilityLabel("uitestlogstream")
        
        let logFont = NSFont.controlContentFont(ofSize: NSFont.systemFontSize(for: .mini))
        logField.isEditable = false
        logField.isSelectable = true
        logField.backgroundColor = .textBackgroundColor
        logField.isRichText = false
        logFieldScroller.heightAnchor.constraint(equalToConstant: logFont.pointSize * 5).isActive = true
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.headIndent = 10
        
        let logLineAttributes: [NSAttributedString.Key : Any] = [
            .font: logFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        globalLogHook =
            LogHook(
                add: {level, message in
                    if let logStorage = logField.textStorage {
                        let prefix = logField.string.isEmpty ? "" : "\n"
                        let timestamp = timeFormatter.string(from: Date())
                        let line = "\(prefix)\(timestamp) [\(level.asString)]: \(message)"
                        logStorage.append(NSAttributedString(string: line, attributes: logLineAttributes))
                        logField.scrollToEndOfDocument(nil)
                    }
                },
                reset: {
                    logField.textStorage?.mutableString.setString("")
                })
    }
    
    @objc private func setAnimationFactor(_ field: NSTextField) {
        if let valueAsDouble = Double(field.stringValue) {
            AnimationHelper.animation_factor = valueAsDouble
        }
        // whether the parse worked or not, display the normalized current value
        field.stringValue = AnimationHelper.animation_factor.description
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

    /// If the "Hide 'Focus Whatdid' Status Item" box is checked, we will (a) set the status item's text opacity to 0%
    /// (making it effectively invisible, though still available to the accesibility API) and (b) make it very wide.
    /// That makes it suitable for screenshotting, if you put it directly to the left of the real whatdid item.
    @objc private func toggleStatusItemVisibility(_ toggle: NSButton) {
        if let button = activatorStatusItem.button {
            var attributes = [NSAttributedString.Key : Any]()
            if toggle.state == .on {
                attributes[.foregroundColor] = NSColor.black.withAlphaComponent(0)
            }
            button.attributedTitle = NSAttributedString(string: button.title, attributes: attributes)
        }
        
    }
    
    @objc private func toggleShowUiConstraints(_ toggle: NSButton) {
        let key = WhatdidControlHooks.showUiConstraintsPrefsKey
        UserDefaults.standard.set(toggle.state == .on, forKey: key)
        wdlog(.debug, "%@ is now %d", key, UserDefaults.standard.bool(forKey: key))
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
                    self.deferButton.title = WhatdidControlHooks.deferCheckboxTitle
                    self.deferButton.isEnabled = true
                    self.deferButton.state = .off
                    self.scheduler.now = date
                }
            case .off:
                scheduler.now = date
            case let x:
                wdlog(.warn, "Unexpected state: %d", x.rawValue)
            }
            
        } else {
            printUtc.stringValue = "ERROR"
            printLocal.stringValue = "ERROR"
        }
    }
}
#endif
