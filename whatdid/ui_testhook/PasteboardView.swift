// whatdid?

import Cocoa

class PasteboardView: NSView {
    
    private let pasteboardButton = NSButton(title: "", target: nil, action: nil)
    private let trashButton = ButtonWithClosure()
    private var pasteboard: NSPasteboard?
    var action: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        doInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInit()
    }
    
    private func doInit() {
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
    
    override func setAccessibilityLabel(_ accessibilityLabel: String?) {
        pasteboardButton.setAccessibilityLabel(accessibilityLabel)
        trashButton.setAccessibilityLabel(accessibilityLabel.map({$0 + "_rm"}))
    }
    
    @objc private func handleButton() {
        if let pasteboard = pasteboard {
            if let data = pasteboard.string(forType: .string) {
                action?(data)
            } else {
                NSLog("no string for pasteboard \(pasteboard.name.rawValue)")
            }
            setUp(pasteboard: nil)
        } else {
            let new = NSPasteboard.withUniqueName()
            new.declareTypes([.string], owner: nil)
            NSLog("created pasteboard: \(new.name.rawValue)")
            setUp(pasteboard: new)
        }
    }

    private func setUp(pasteboard: NSPasteboard?) {
        if let old = self.pasteboard {
            NSLog("released pasteboard: \(old.name.rawValue)")
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
