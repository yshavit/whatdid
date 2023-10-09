//
//  PrefsAboutPaneController.swift
//  whatdid
//
//  Created by Yuval Shavit on 10/9/23.
//  Copyright © 2023 Yuval Shavit. All rights reserved.
//

import Cocoa
#if canImport(Sparkle)
import Sparkle
#endif

class PrefsAboutPaneController: NSViewController {

    
    @IBOutlet var shortVersion: NSTextField!
    @IBOutlet var copyright: NSTextField!
    @IBOutlet var fullVersion: NSTextField!
    @IBOutlet var shaVersion: NSButton!
    @IBOutlet var githubShaInfo: NSStackView!
    @IBOutlet weak var updaterOptions: NSStackView!
    
    override func viewDidLoad() {
        shortVersion.stringValue = shortVersion.stringValue.replacingBracketedPlaceholders(with: [
            "version": Version.short
        ])
        copyright.stringValue = copyright.stringValue.replacingBracketedPlaceholders(with: [
            "copyright": Version.copyright
        ])
        fullVersion.stringValue = fullVersion.stringValue.replacingBracketedPlaceholders(with: [
            "fullversion": Version.full
        ])
        shaVersion.title = shaVersion.title.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha
        ])
        shaVersion.toolTip = shaVersion.toolTip?.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha.replacingOccurrences(of: ".dirty", with: "")
        ])
        githubShaInfo.isHidden = !NSEvent.modifierFlags.contains(.command)
        #if !canImport(Sparkle)
        updaterOptions.removeFromSuperview()
        updaterOptions = nil
        #endif
    }
    
    @IBInspectable
    dynamic var autoCheckUpdates: Bool {
        get {
            #if canImport(Sparkle)
            AppDelegate.instance.updaterController.updater.automaticallyChecksForUpdates
            #else
            // This var gets read (via binding) at controller load, before we have a chance to remove the updater options stack.
            // That means we do expect it to get invoked even if there's no Sparkle.
            false
            #endif
        }
        set (value) {
            #if canImport(Sparkle)
            AppDelegate.instance.updaterController.updater.automaticallyChecksForUpdates = value
            #else
            wdlog(.error, "improperly invoked autoCheckUpdates:set without sparkle available")
            #endif
        }
    }
    
    @IBInspectable
    dynamic var includeAlphaReleases: Bool {
        get {
            #if canImport(Sparkle)
            Prefs.updateChannels.contains(.alpha)
            #else
            // This var gets read (via binding) at controller load, before we have a chance to remove the updater options stack.
            // That means we do expect it to get invoked even if there's no Sparkle.
            false
            #endif
        }
        set (shouldIncludeAlphas) {
            #if canImport(Sparkle)
            var newChannels = Prefs.updateChannels
            if shouldIncludeAlphas {
                newChannels.formUnion([.alpha])
            } else {
                newChannels.subtract([.alpha])
            }
            Prefs.updateChannels = newChannels
            #else
            wdlog(.error, "improperly invoked includeAlphaReleases:set without sparkle available")
            #endif
        }
    }
    
    @IBAction func checkUpdateNow(_ sender: Any) {
        #if canImport(Sparkle)
        AppDelegate.instance.updaterController.checkForUpdates(sender)
        #else
        wdlog(.error, "improperly invoked checkUpdateNow without sparkle available")
        #endif
    }
    
    @IBAction func href(_ sender: NSButton) {
        if let location = sender.toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            wdlog(.warn, "invalid href: %@", sender.toolTip ?? "<nil>")
        }
    }
}
