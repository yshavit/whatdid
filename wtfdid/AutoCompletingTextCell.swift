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
        print("setting autocomplete for cell")
        if editor == nil {
            editor = AutoCompletingTextView()
        }
        editor?.autoCompleteLookups = lookups
    }
    
    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return editor// ?? super.fieldEditor(for: controlView)
    }
    
    private class AutoCompletingTextView : NSTextView {
        
        var autoCompleteLookups : (String) -> [String] = {(current) in []}
        
//        override var rangeForUserCompletion: NSRange {
//            get {
//                let fromSuper = super.rangeForUserCompletion
//                print("super range: location=\(fromSuper.location), length=\(fromSuper.length)")
//                return fromSuper
//                return NSRange(location: 0, length: fromSuper.location + fromSuper.length)
//            }
//        }
        
//        override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
//            let results = autoCompleteLookups(string)
//            print("completions for \"\(string)\" in \(charRange), indexOfSelectedItem=\(index.pointee): \(results)")
//            print("from super: \(super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index))")
//            return results
//        }
        
//        override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
//            print("insertCompetion of \"\(word)\":\(charRange), movement=\(movement), isFinal=\(flag)")
//            if !flag {
//                super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
//            }
//        }
    }
}
