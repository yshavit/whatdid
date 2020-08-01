// whatdid?

import Cocoa

class ButtonWithClosure: NSButton {

    private var handlers = [(NSButton) -> Void]()
    
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        let result = super.sendAction(action, to: target) || (!handlers.isEmpty)
        handlers.forEach {handler in handler(self)}
        return result
    }
    
    func onPress(_ handler: @escaping (NSButton) -> Void) {
        handlers.append(handler)
    }
    
}
