// whatdidUITests?

import XCTest

extension XCUIElement {
    
    func grabFocus() {
        if !hasFocus {
            click()
        }
    }
    
    var hasFocus: Bool {
        return (self.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }
    
    var focusedChild: XCUIElement {
        get {
            let focusedElems = children(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus = true")).allElementsBoundByIndex
            XCTAssertEqual(focusedElems.count, 1)
            return focusedElems[0]
        }
    }
    
    var stringValue: String {
        return value as! String
    }
    
    func backtab() {
        typeKey(.tab, modifierFlags: .shift)
    }
    
    /// Basically a safer version of `isHittable` that also checks if the element exists at all.
    var isVisible: Bool {
        get {
            return exists && isHittable
        }
    }
    
    func deleteText(andReplaceWith replacement: String? = nil) {
        click()
        typeKey(.downArrow)
        typeKey(.upArrow, modifierFlags:[.shift, .function])
        typeKey(.delete, modifierFlags:[])
        if replacement != nil {
            typeText(replacement!)
        }
    }
    
    func typeKey(_ key: XCUIKeyboardKey) {
        typeKey(key, modifierFlags: [])
    }
    
    func assertVisible() {
        _ = frame // just trying to get it will fail if the element isn't visible
    }
    
    var simpleDescription: String {
        var result = "\(elementType.description) id=\"\(identifier)\""
        if !title.isEmpty {
            result += ", title=\"\(title)\""
        }
        func addBool(title: String, if set: Bool) {
            if set {
                result += ", \(title)"
            }
        }
        result += "["
        addBool(title: "exists", if: exists)
        addBool(title: "hittable", if: isHittable)   <-- causes infinite loop when looking up the ScrollView
        result += "]"
        return result
    }
    
    func printAccessibilityTree() {
        func buildTree(_ curr: XCUIElement, to resultLines: inout [String], depth: Int = 0) {
            let indent = String(repeating: " ", count: depth * 4)
            if depth > 5 {
                resultLines.append("\(indent)...")
            } else {
                let children = curr.children(matching: .any)
                let childrenDescription = children.count == 1 ? "1 child" : "\(children.count) children"
                resultLines.append("\(indent)\(curr.simpleDescription): \(childrenDescription)")
                children.allElementsBoundByIndex.forEach { buildTree($0, to: &resultLines, depth: depth + 1) }
            }
        }
        let header = String(repeating: "=", count: 72)
        var lines = [String]()
        buildTree(self, to: &lines)
        print(header)
        lines.forEach { print($0) }
        print(header)
    }
}

extension XCUIElement.ElementType {
    var description: String {
        switch self {
        case .activityIndicator: return "activityIndicator"
        case .alert: return "alert"
        case .any: return "any"
        case .application: return "application"
        case .browser: return "browser"
        case .button: return "button"
        case .cell: return "cell"
        case .checkBox: return "checkBox"
        case .collectionView: return "collectionView"
        case .colorWell: return "colorWell"
        case .comboBox: return "comboBox"
        case .datePicker: return "datePicker"
        case .decrementArrow: return "decrementArrow"
        case .dialog: return "dialog"
        case .disclosureTriangle: return "disclosureTriangle"
        case .dockItem: return "dockItem"
        case .drawer: return "drawer"
        case .grid: return "grid"
        case .group: return "group"
        case .handle: return "handle"
        case .helpTag: return "helpTag"
        case .icon: return "icon"
        case .image: return "image"
        case .incrementArrow: return "incrementArrow"
        case .key: return "key"
        case .keyboard: return "keyboard"
        case .layoutArea: return "layoutArea"
        case .layoutItem: return "layoutItem"
        case .levelIndicator: return "levelIndicator"
        case .link: return "link"
        case .map: return "map"
        case .matte: return "matte"
        case .menu: return "menu"
        case .menuBar: return "menuBar"
        case .menuBarItem: return "menuBarItem"
        case .menuButton: return "menuButton"
        case .menuItem: return "menuItem"
        case .navigationBar: return "navigationBar"
        case .other: return "other"
        case .outline: return "outline"
        case .outlineRow: return "outlineRow"
        case .pageIndicator: return "pageIndicator"
        case .picker: return "picker"
        case .pickerWheel: return "pickerWheel"
        case .popUpButton: return "popUpButton"
        case .popover: return "popover"
        case .progressIndicator: return "progressIndicator"
        case .radioButton: return "radioButton"
        case .radioGroup: return "radioGroup"
        case .ratingIndicator: return "ratingIndicator"
        case .relevanceIndicator: return "relevanceIndicator"
        case .ruler: return "ruler"
        case .rulerMarker: return "rulerMarker"
        case .scrollBar: return "scrollBar"
        case .scrollView: return "scrollView"
        case .searchField: return "searchField"
        case .secureTextField: return "secureTextField"
        case .segmentedControl: return "segmentedControl"
        case .sheet: return "sheet"
        case .slider: return "slider"
        case .splitGroup: return "splitGroup"
        case .splitter: return "splitter"
        case .staticText: return "staticText"
        case .statusBar: return "statusBar"
        case .statusItem: return "statusItem"
        case .stepper: return "stepper"
        case .`switch`: return "`switch`"
        case .tab: return "tab"
        case .tabBar: return "tabBar"
        case .tabGroup: return "tabGroup"
        case .table: return "table"
        case .tableColumn: return "tableColumn"
        case .tableRow: return "tableRow"
        case .textField: return "textField"
        case .textView: return "textView"
        case .timeline: return "timeline"
        case .toggle: return "toggle"
        case .toolbar: return "toolbar"
        case .toolbarButton: return "toolbarButton"
        case .valueIndicator: return "valueIndicator"
        case .webView: return "webView"
        case .window: return "window"
        case .touchBar: return "touchBar"

        @unknown default:
            return "(unknown type)"
        }
    }
}
