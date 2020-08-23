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
        let builder = AutocompleteFieldBuilder()
        strongReferences.append(builder)
        builder.build(adder: adder)
    }
    
}

fileprivate class AutocompleteFieldBuilder: TestComponent {
    
    private let resultField = NSTextField(labelWithString: "")
    private let autocompleField = AutoCompletingField()
    
    func build(adder: (NSView) -> Void) {
        let options = NSTextField(string: "one,two,three,four,five,six,seven")
        options.target = self
        options.action = #selector(setAutocompleterOptions(_:))
        
        autocompleField.target = self
        autocompleField.action = #selector(autocompleteAction(_:))
        
        let optionsStack = NSStackView(orientation: .horizontal)
        optionsStack.addArrangedSubview(NSTextField(labelWithString: "options: "))
        optionsStack.addArrangedSubview(options)
        
        resultField.isBordered = true
        resultField.isBezeled = true
        resultField.bezelStyle = .roundedBezel
        let resultStack = NSStackView(orientation: .horizontal)
        resultStack.addArrangedSubview(NSTextField(labelWithString: "result: "))
        resultStack.addArrangedSubview(resultField)
        
        adder(optionsStack)
        adder(resultStack)
        adder(autocompleField)
        optionsStack.arrangedSubviews[1].leadingAnchor.constraint(equalTo: resultStack.arrangedSubviews[1].leadingAnchor).isActive = true
        
        options.nextKeyView = autocompleField
        autocompleField.nextKeyView = options
        
        setAutocompleterOptions(options)
    }
    
    @objc private func autocompleteAction(_ sender: NSTextField) {
        resultField.stringValue = autocompleField.stringValue
    }
    
    @objc private func setAutocompleterOptions(_ sender: NSTextField) {
        let options = sender.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces)}
        autocompleField.options = options
    }
    
    
}

fileprivate protocol TestComponent {
    func build(adder: (NSView) -> Void)
}

#endif
