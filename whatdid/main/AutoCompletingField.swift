// whatdid?

import Cocoa

class AutoCompletingField: TextFieldWithPopup, NSAccessibilityGroup {
    
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    
    var onAction: (AutoCompletingField) -> Void = {_ in}
    var optionsLookupOnFocus: (() -> [String])?
    
    private var optionsList: TextOptionsList {
        contents as! TextOptionsList
    }
    
    override func finishInit() {
        self.contents = TextOptionsList()
        target = self
        action = #selector(textFieldViewAction(_:))
    }
    
    @objc private func textFieldViewAction(_ sender: NSTextField) {
        onAction(self)
    }
    
    override func becomeFirstResponder() -> Bool {
        var optionsLocal: [String]?
        if let optionsLookupOnFocus = optionsLookupOnFocus {
            optionsLocal = optionsLookupOnFocus()
        }
        let result = super.becomeFirstResponder()
        if result, let optionsLocal = optionsLocal {
            options = optionsLocal
        }
        return result
    }

    var options: [String] {
        get {
            return optionsList.options
        }
        set (values) {
            optionsList.options = values
        }
    }
}
