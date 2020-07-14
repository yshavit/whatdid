//
//  TaskAdditionView.swift
//  wtfdid
//
//  Created by Yuval Shavit on 12/23/19.
//  Copyright © 2019 Yuval Shavit. All rights reserved.
//

import Cocoa

class TaskAdditionViewController: NSViewController {
    @IBOutlet var contentView: NSView!
    
    var project: String!
    @IBOutlet weak var projectField: NSTextField!
    @IBOutlet weak var taskField: NSTextField!
    @IBOutlet weak var notesField: NSTextField!
    
    override func loadView() {
        print("here loadView")
        Bundle.main.loadNibNamed("TaskAdditionView", owner: self, topLevelObjects: nil)
    }
    
/*
    override init(frame: NSRect) {
        super.init(frame: frame)
        if  {
            addSubview(contentView)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
*/
}
