// whatdidUITests?

import XCTest

extension XCUIKeyboardKey {
    var prettyString: String {
        switch self {
        case .delete: return "delete"
        case .`return`: return "return"
        case .enter: return "enter"
        case .tab: return "tab"
        case .space: return "space"
        case .escape: return "escape"
        case .upArrow: return "upArrow"
        case .downArrow: return "downArrow"
        case .leftArrow: return "leftArrow"
        case .rightArrow: return "rightArrow"
        case .F1: return "F1"
        case .F2: return "F2"
        case .F3: return "F3"
        case .F4: return "F4"
        case .F5: return "F5"
        case .F6: return "F6"
        case .F7: return "F7"
        case .F8: return "F8"
        case .F9: return "F9"
        case .F10: return "F10"
        case .F11: return "F11"
        case .F12: return "F12"
        case .F13: return "F13"
        case .F14: return "F14"
        case .F15: return "F15"
        case .F16: return "F16"
        case .F17: return "F17"
        case .F18: return "F18"
        case .F19: return "F19"
        case .forwardDelete: return "forwardDelete"
        case .home: return "home"
        case .end: return "end"
        case .pageUp: return "pageUp"
        case .pageDown: return "pageDown"
        case .clear: return "clear"
        case .help: return "help"
        case .capsLock: return "capsLock"
        case .shift: return "shift"
        case .control: return "control"
        case .option: return "option"
        case .command: return "command"
        case .rightShift: return "rightShift"
        case .rightControl: return "rightControl"
        case .rightOption: return "rightOption"
        case .rightCommand: return "rightCommand"
        case .secondaryFn: return "secondaryFn"

        default:
            return rawValue.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? rawValue
        }
    }
}
