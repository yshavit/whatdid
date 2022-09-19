// whatdid?

import Cocoa

class AutoCompletingField: TextFieldWithPopup, NSAccessibilityGroup {
    
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    
    var onAction: (AutoCompletingField) -> Void = {_ in}
    var optionsLookup: (() -> [String])?
    
    /// Characters to ignore when reporting the accessibility value
    var accessibilityStringIgnoredChars: CharacterSet {
        get {
            optionsList.accessibilityStringIgnoredChars
        } set (value) {
            optionsList.accessibilityStringIgnoredChars = value
        }
    }
    
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
    
    override func showOptions() {
        if let optionsLookup = optionsLookup {
            options = optionsLookup()
        }
        super.showOptions()
    }
    
    func makeFirstResponderWithoutShowingPopup() {
        guard let window = window else {
            return
        }
        let prevSetting = automaticallyShowPopup
        automaticallyShowPopup = false
        defer {
            automaticallyShowPopup = prevSetting
        }
        window.makeFirstResponder(self)
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
