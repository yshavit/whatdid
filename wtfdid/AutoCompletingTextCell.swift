//
//  AutCompletingTextCell.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/18/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//

import Cocoa

class AutoCompletingTextCell: NSTextFieldCell {
    
    private var editor : AutoCompletingTextView?
    
    func setAutoCompleteLookups(_ lookups : @escaping (String) -> [String]) {
        if editor == nil {
            editor = AutoCompletingTextView()
        }
        editor?.autoCompleteLookups = lookups
    }
    
    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return editor ?? super.fieldEditor(for: controlView)
    }
    
    private class AutoCompletingTextView : NSTextView {
        
        var autoCompleteLookups : (String) -> [String] = {(current) in []}
        
        override var rangeForUserCompletion: NSRange {
            get {
                let original = super.rangeForUserCompletion
                let mine = translateRange(original)
                print("rangeForUserCompletion:")
                print("  super: location=\(original.location), length=\(original.length)")
                print("  mine:  location=\(mine.location), length=\(mine.length)")
                return mine
            }
        }
        
        func translateRange(_ original: NSRange) -> NSRange {
            let mine : NSRange
            if original.location == 0 {
                mine = original
            } else if (original.length == 0) {
                // This means it found a space; return a range that extends up to it, inclusive
                mine = NSRange(location: 0, length: original.location)
            } else {
                mine = NSRange(location: 0, length: original.location - 1)
            }
            print("translated \(original) -> \(mine)")
            return mine
        }
        
        override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
            let down = translateRange(charRange)
            print("completions for range \(down)")
            return super.completions(forPartialWordRange: down, indexOfSelectedItem: index)
//            let results = autoCompleteLookups(string)
////            print("completions for \"\(string)\" in \(charRange), indexOfSelectedItem=\(index.pointee): \(results)")
////            print("from super: \(super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index))")
//            return results
        }
        
        override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
            let currentEventChars = NSApp.currentEvent?.characters
            var called = false
            if !(currentEventChars?.contains(" ") ?? false) {
                called = true
                super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: false)
            }

            print("insertCompletion(\"\(word)\", range=\(charRange), movement=\(movement), isFinal=\(flag), currentEvent.characters=\"\(currentEventChars)\"), called=\(called)")

        }
    }
}
