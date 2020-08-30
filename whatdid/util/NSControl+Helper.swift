// whatdid?

import Cocoa

extension NSTextView {
    private static let commandKey = NSEvent.ModifierFlags.command.rawValue
    private static let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue
    
    /// Copied from [SO#970707](https://stackoverflow.com/a/54492165/1076640) with slight modifications.
    override open func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown {
            let action: Selector?
            if checkFlags(on: event, for: NSTextView.commandKey) {
                switch event.charactersIgnoringModifiers! {
                case "x":
                    action = #selector(NSText.cut(_:))
                case "c":
                    action = #selector(NSText.copy(_:))
                case "v":
                    action = #selector(NSText.paste(_:))
                case "z":
                    action = Selector(("undo:"))
                case "a":
                    action = #selector(NSResponder.selectAll(_:))
                default:
                    action = nil
                    break
                }
            } else if checkFlags(on: event, for: NSTextView.commandShiftKey) && event.charactersIgnoringModifiers == "Z" {
                 action = Selector(("redo:"))
            } else {
                action = nil
            }
            if let useAction = action, NSApp.sendAction(useAction, to: nil, from: self) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func checkFlags(on event: NSEvent, for flags: UInt) -> Bool {
        return (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == flags
    }
}
