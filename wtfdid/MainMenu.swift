//
//  MainMenuController.swift
//  wtfdid
//
//  Created by Yuval Shavit on 12/23/19.
//  Copyright © 2019 Yuval Shavit. All rights reserved.
//

import Cocoa

class MainMenu: NSObject, NSMenuDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    @IBOutlet weak var addTaskItem: NSMenuItem?
    var taskAdditionView: TaskAdditionView?
    
    override func awakeFromNib() {
        statusItem.button?.title = "✐"
        statusItem.menu = statusMenu
        statusMenu.delegate = self
        
        if let item = addTaskItem {
            taskAdditionView = TaskAdditionView()
            item.view = taskAdditionView?.contentView
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        // taskAdditionView?.projectField.becomeFirstResponder()
    }
    
    @objc func selectedTaskAdditionItem() {
        print("here: selectedTaskAdditionItem")
    }
}
