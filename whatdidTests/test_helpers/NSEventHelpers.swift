// whatdidTests?

import XCTest
@testable import Whatdid

func sendEvents(simulateTyping string: String, into view: NSView) {
    for event in createEvents(simulateTyping: string, into: view) {
        NSApp.sendEvent(event)
    }
}

func createEvents(simulateTyping string: String, into view: NSView, withModifiers mods: NSEvent.ModifierFlags = []) -> [NSEvent] {
    guard let window = view.window else {
        wdlog(.error, "no window")
        return []
    }
    var results = [NSEvent]()
    let viewFrame = view.frame
    let viewFrameMid = NSPoint(x: viewFrame.midX, y: viewFrame.midY)
    let windowPoint = view.convert(viewFrameMid, to: nil)
    for char in string {
        guard let keyCode = charMap[char] else {
            wdlog(.error, "couldn't get key code for: %@", String(char))
            return []
        }
        var lcChar = char
        var charMods = NSEvent.ModifierFlags(arrayLiteral: mods)
        if char.isUppercase {
            lcChar = char.lowercased().first!
            charMods.insert(.shift)
        }
        for eventType in [NSEvent.EventType.keyDown, NSEvent.EventType.keyUp] {
            guard let event = NSEvent.keyEvent(
                    with: eventType,
                    location: windowPoint,
                    modifierFlags: charMods,
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    characters: String(char),
                    charactersIgnoringModifiers: String(lcChar),
                    isARepeat: false,
                    keyCode: keyCode)
            else {
                wdlog(.error, "couldn't generate event")
                return []
            }
            results.append(event)
        }
    }
    return results
}

fileprivate let charMap: [Character: UInt16] = [
    "0" : 0x1D,
    "1" : 0x12,
    "2" : 0x13,
    "3" : 0x14,
    "4" : 0x15,
    "5" : 0x17,
    "6" : 0x16,
    "7" : 0x1A,
    "8" : 0x1C,
    "9" : 0x19,
    "a" : 0x00,
    "b" : 0x0B,
    "c" : 0x08,
    "d" : 0x02,
    "e" : 0x0E,
    "f" : 0x03,
    "g" : 0x05,
    "h" : 0x04,
    "i" : 0x22,
    "j" : 0x26,
    "k" : 0x28,
    "l" : 0x25,
    "m" : 0x2E,
    "n" : 0x2D,
    "o" : 0x1F,
    "p" : 0x23,
    "q" : 0x0C,
    "r" : 0x0F,
    "s" : 0x01,
    "t" : 0x11,
    "u" : 0x20,
    "v" : 0x09,
    "w" : 0x0D,
    "x" : 0x07,
    "y" : 0x10,
    "z" : 0x06,
    "\\" : 0x2A,
    ","  : 0x2B,
    "="  : 0x18,
    "`"  : 0x32,
    "["  : 0x21,
    "-"  : 0x1B,
    "."  : 0x2F,
    "\"" : 0x27,
    "]"  : 0x1E,
    ";"  : 0x29,
    "/"  : 0x2C,
    "\r" : 0x24,
    " "  : 0x31,
    "\t" : 0x30,
]
