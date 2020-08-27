// whatdid?
#if UI_TEST

import Cocoa

class UiTestWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet var mainStack: NSStackView!
    @IBOutlet var componentSelector: NSPopUpButton!
    
    convenience init() {
        self.init(windowNibName: "UiTestWindow")
    }
    
    override func awakeFromNib() {
        add(AutocompleteComponent())
        add(ButtonWithClosureComponent())
    }
    
    private func add(_ use: TestComponent) {
        var className = String(describing: type(of: use))
        let suffix = "Component"
        if className.hasSuffix(suffix) {
            className = String(className.dropLast(suffix.count))
        }
        componentSelector.addItem(withTitle: className)
        let item = componentSelector.itemArray[componentSelector.itemArray.count - 1]
        item.representedObject = use
    }
    
    func show() {
        _ = window?.title // force the window nib to load
        componentSelector.selectItem(at: 0) // the zeroith item
        showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func selectComponentToTest(_ sender: NSPopUpButton) {
        mainStack.views.forEach { $0.removeFromSuperview() }
        fitToSize()
        if let use = sender.selectedItem?.representedObject as? TestComponent {
            use.build {
                self.mainStack.addArrangedSubview($0)
                self.fitToSize()
            }
        }
    }
    
    private func fitToSize() {
        if let actualWindow = window, let contentView = window?.contentView {
            actualWindow.setContentSize(contentView.fittingSize)
        }
    }
}

fileprivate class ButtonWithClosureComponent: TestComponent {
    func build(adder: @escaping (NSView) -> Void) {
        let button = ButtonWithClosure()
        button.useAutoLayout()
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
            adder(label)
        }
    }
}

fileprivate class AutocompleteComponent: TestComponent {
    
    private let resultField = NSTextField(labelWithString: "")
    private let autocompleField = AutoCompletingField()
    
    func build(adder: (NSView) -> Void) {
        let options = NSTextField(string: "")
        options.target = self
        options.action = #selector(setAutocompleterOptions(_:))
        options.setAccessibilityIdentifier("test_defineoptions")
        
        autocompleField.target = self
        autocompleField.action = #selector(autocompleteAction(_:))
        autocompleField.setAccessibilityIdentifier("test_autocomplete")
        
        let optionsStack = NSStackView(orientation: .horizontal)
        optionsStack.addArrangedSubview(NSTextField(labelWithString: "options: "))
        optionsStack.addArrangedSubview(options)
        
        resultField.isBordered = true
        resultField.isBezeled = true
        resultField.bezelStyle = .roundedBezel
        resultField.setAccessibilityIdentifier("test_result")
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
    func build(adder: @escaping (NSView) -> Void)
}

#endif
