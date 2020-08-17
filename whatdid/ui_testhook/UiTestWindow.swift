// whatdid?
#if UI_TEST

import Cocoa

class UiTestWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet var mainStack: NSStackView!
    
    convenience init() {
        self.init(windowNibName: "UiTestWindow")
    }
    
    func show(_ mode: DebugMode) {
        _ = window?.title // force the window nib to load
        mainStack.subviews.forEach {$0.removeFromSuperview()}
        let adder: ((NSView) -> Void) = { self.mainStack.addArrangedSubview($0) }
        let viewToAdd: NSView
        switch mode {
        case .buttonWithClosure:
            viewToAdd = buttonWithClosure(adder: adder)
        case .autoCompleter:
            viewToAdd = autocompleter(adder: adder)
        }
        mainStack.addArrangedSubview(viewToAdd)
        showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func buttonWithClosure(adder: (NSView) -> Void) -> NSView {
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
        return button
    }
    
    func autocompleter(adder: (NSView) -> Void) -> NSView {
        let field = AutoCompletingField()
        adder(field)
        return field
    }

}

#endif
