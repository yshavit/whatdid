// whatdid?

import Cocoa

class ButtonWithClosure: NSButton {

    private var handlers = [(NSButton) -> Void]()
    
    convenience init(label: String, _ handler: @escaping (NSButton) -> Void) {
        self.init(title: label, target: nil, action: nil)
        onPress(handler)
    }
    
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        let result = super.sendAction(action, to: target) || (!handlers.isEmpty)
        handlers.forEach {handler in handler(self)}
        return result
    }
    
    func onPress(sendInitialState: Bool = false, _ handler: @escaping (NSButton) -> Void) {
        handlers.append(handler)
        if (sendInitialState) {
            handler(self)
        }
    }
    
}
