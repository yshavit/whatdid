// whatdid?
#if UI_TEST

import Cocoa

class UiTestWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet var mainStack: NSStackView!
    private var strongReferences = [Any]()
    
    convenience init() {
        self.init(windowNibName: "UiTestWindow")
    }
    
    func show(_ mode: DebugMode) {
        _ = window?.title // force the window nib to load
        mainStack.subviews.forEach {$0.removeFromSuperview()}
        let adder: ((NSView) -> Void) = { self.mainStack.addArrangedSubview($0) }
        switch mode {
        case .buttonWithClosure:
            buttonWithClosure(adder: adder)
        case .autoCompleter:
            autocompleter(adder: adder)
        }
        showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        strongReferences.removeAll()
    }
    
    func buttonWithClosure(adder: (NSView) -> Void) {
        let button = ButtonWithClosure()
        adder(button)
        button.setAccessibilityLabel("button_with_closure")
        var counter = Atomic(wrappedValue: 1)
        button.onPress {button in
            let currentCount = counter.map { $0 + 1}
            let labelString = "count=\(currentCount), pressed on self=\(true)"
            let label = NSTextField(labelWithString: labelString)
            label.setAccessibilityEnabled(true)
            label.setAccessibilityLabel(labelString)
            label.setAccessibilityIdentifier("dynamiclabel_\(currentCount)")
            self.mainStack.addArrangedSubview(label)
        }
    }
    
    func autocompleter(adder: (NSView) -> Void) {
        let options = NSTextField(string: "one,two,three,four,five,six,seven")
        options.target = self
        options.action = #selector(setAutocompleterOptions(_:))
        adder(options)
        
        adder(AutoCompletingField())
        setAutocompleterOptions(options)
    }
    
    @objc private func setAutocompleterOptions(_ sender: NSTextField) {
        let options = sender.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces)}
        mainStack.arrangedSubviews.compactMap { $0 as? AutoCompletingField } .forEach { $0.options = options }
    }

}

#endif
