// whatdid?

import Cocoa

class PasteboardView: WdView {
    
    private let pasteboardButton = NSButton(title: "", target: nil, action: nil)
    private let trashButton = ButtonWithClosure()
    private var pasteboard: NSPasteboard?
    var action: ((String) -> Void)?
    
    override func wdViewInit() {
        pasteboardButton.target = self
        pasteboardButton.action = #selector(self.handleButton)
        pasteboardButton.controlSize = .small
        pasteboardButton.font = NSFont.userFixedPitchFont(ofSize: NSFont.systemFontSize(for: .mini))
        
        trashButton.bezelStyle = .regularSquare
        trashButton.title = "x"
        trashButton.alignment = .center
        trashButton.controlSize = pasteboardButton.controlSize
        trashButton.onPress {_ in
            self.setUp(pasteboard: nil)
        }
        
        setUp(pasteboard: nil)

        let box = NSStackView(orientation: .horizontal)
        box.alignment = .centerY
        box.addArrangedSubview(pasteboardButton)
        box.addArrangedSubview(trashButton)
        addSubview(box)
        box.anchorAllSides(to: self)
    }
    
    func copyStyle(to other: NSButton) {
        other.font = pasteboardButton.font
        other.controlSize = pasteboardButton.controlSize
        other.bezelStyle = pasteboardButton.bezelStyle
    }
    
    override func setAccessibilityLabel(_ accessibilityLabel: String?) {
        pasteboardButton.setAccessibilityLabel(accessibilityLabel)
        trashButton.setAccessibilityLabel(accessibilityLabel.map({$0 + "_rm"}))
    }
    
    @objc private func handleButton() {
        if let pasteboard = pasteboard {
            if let data = pasteboard.string(forType: .string) {
                action?(data)
            } else {
                wdlog(.warn, "no string for pasteboard %@", pasteboard.name.rawValue)
            }
            setUp(pasteboard: nil)
        } else {
            let new = NSPasteboard.withUniqueName()
            new.declareTypes([.string], owner: nil)
            wdlog(.debug, "created pasteboard: %@", new.name.rawValue)
            setUp(pasteboard: new)
        }
    }

    private func setUp(pasteboard: NSPasteboard?) {
        if let old = self.pasteboard {
            wdlog(.debug, "released pasteboard: %@", old.name.rawValue)
            old.releaseGlobally()
        }
        self.pasteboard = pasteboard
        if let pasteboard = pasteboard {
            pasteboardButton.title = pasteboard.name.rawValue
            trashButton.isEnabled = true
        } else {
            pasteboardButton.title = "generate pasteboard"
            trashButton.isEnabled = false
        }
    }
}
