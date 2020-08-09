// whatdid?
#if UI_TEST
import Cocoa

extension PtnViewController {
    
    func addJsonFlatEntryField() {
        let jsonField = NSTextField()
        jsonField.setAccessibilityLabel("uihook_flatentryjson")
        jsonField.action = #selector(setEntriesViaJson)
        topStack.addArrangedSubview(jsonField)
    }
    
    func populateJsonFlatEntryField() {
        let entries = AppDelegate.instance.model.listEntries(since: Date.distantPast)
        textField.stringValue = FlatEntry.serialize(entries)
    }
    
    @objc private func setEntriesViaJson(_ field: NSTextField) {
        let entries = FlatEntry.deserialize(from: textField.stringValue)
        AppDelegate.instance.model.clearAll()
        entries.forEach {AppDelegate.instance.model.add($0, andThen: {})}
    }
    
    private var textField: NSTextField {
        return topStack
            .arrangedSubviews
            .filter {$0.accessibilityLabel() == "uihook_flatentryjson"}
            .first as! NSTextField
    }
}

#endif
