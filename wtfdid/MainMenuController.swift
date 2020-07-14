//
//  MainMenuController.swift
//  wtfdid
//
//  Created by Yuval Shavit on 12/23/19.
//  Copyright © 2019 Yuval Shavit. All rights reserved.
//

import Cocoa

class MainMenuController: NSObject, NSMenuDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    @IBOutlet weak var taskAdditionView: TaskAdditionView!
    @IBOutlet weak var taskAdditionWindow: NSPanel!
    
    override func awakeFromNib() {
        statusItem.button?.title = "✐"
        statusItem.menu = statusMenu
        statusMenu.delegate = self
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        taskAdditionWindow.makeKeyAndOrderFront(self)
    }
}
