// whatdid?

import Cocoa
import KeyboardShortcuts

class PtnViewController: NSViewController {
    
    public static let CURRENT_TUTORIAL_VERSION = 0

    @IBOutlet var topStack: NSStackView!
    @IBOutlet var headerText: NSTextField!
    
    @IBOutlet weak var prefsButton: NSButton!
    @IBOutlet weak var projectField: AutoCompletingField!
    @IBOutlet weak var taskField: AutoCompletingField!
    @IBOutlet weak var noteField: NSTextField!
    
    @IBOutlet weak var projectTaskFinder: ProjectTaskFinder!
    
    @IBOutlet var goals: GoalsView!
    
    @IBOutlet weak var snoozeButton: NSButton!
    private var snoozeUntil : Date?
    @IBOutlet weak var snoozeExtraOptions: NSPopUpButton!
    private var snoozeOptionsUpdateSpinner: NSProgressIndicator?
    @IBOutlet weak var snoozeUntilTomorrow: NSMenuItem!
    
    private var optionIsPressed = false
    
    var hooks: PtnViewDelegate?
    
    var scheduler: Scheduler = DefaultScheduler.instance
    
    private var modelOverride: Model?
    
    private var model: Model {
        modelOverride ?? AppDelegate.instance.model
    }

    func override(model: Model) {
        modelOverride = model
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        projectField.placeholderString = "project"
        taskField.placeholderString = "task"
        for field in [projectField, taskField, noteField] {
            if let plainString = field?.placeholderString {
                field?.placeholderAttributedString = NSAttributedString(
                    string: plainString,
                    attributes: [.foregroundColor: NSColor.secondarySelectedControlColor])
            }
        }
        projectField.optionsLookup = {
            self.model.listProjects()
        }
        taskField.optionsLookup = {
            self.model.listTasks(project: self.projectField.stringValue)
        }
        projectField.onTextChange = {
            self.taskField.stringValue = ""
        }
        projectField.onAction = self.projectOrTaskAction
        taskField.onAction = self.projectOrTaskAction
        
        headerText.placeholderString = headerText.stringValue
        
        projectTaskFinder.onOpen = {
            var options = [ProjectAndTask]()
            for project in self.model.listProjects() {
                for task in self.model.listTasks(project: project) {
                    options.append(ProjectAndTask(project: project, task: task))
                }
            }
            let saveState = ProjectTaskFinder.SaveState(
                project: self.projectField.stringValue,
                task: self.taskField.stringValue,
                notes: self.noteField.stringValue)
            return (saveState, options)
        }
        projectTaskFinder.previewSelect = {pt in
            self.projectField.stringValue = pt.project
            self.taskField.stringValue = pt.task
        }
        projectTaskFinder.onSelect = {pt in
            /// Run an action after a small delay.
            /// Note: this is really just a minor animation, not a "functional" delay, so we're going
            /// to use the real/system mechanism instead of DefaultScheduler.instance.
            func delayed(_ actions: [() -> Void]) {
                if actions.isEmpty {
                    return
                }
                let action = actions[0]
                let rest = Array(actions.dropFirst())
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.025, qos: .userInteractive, flags: []) {
                    action()
                    delayed(rest)
                }
            }
            self.closeFind(self)
            self.projectField.makeFirstResponderWithoutShowingPopup()
            delayed([
                { self.projectField.stringValue = pt.project },
                { self.taskField.makeFirstResponderWithoutShowingPopup() },
                { self.taskField.stringValue = pt.task },
                { self.view.window?.makeFirstResponder(self.noteField) }
            ])
        }
        projectTaskFinder.onCancel = {prev in
            self.projectField.stringValue = prev.project
            self.taskField.stringValue = prev.task
            self.noteField.stringValue = prev.notes
            self.closeFind(self)
        }
        projectTaskFinder.isHidden = true
        projectTaskFinder.setAccessibilityIdentifier("ptn_find")
        projectTaskFinder.setAccessibilityRole(.group)
        
        if let view = view as? PtnTopLevelStackView {
            view.parent = self
        } else {
            wdlog(.warn, "Couldn't set top-level stack view's parent to self")
        }
    }
    
    private func setNotesPlaceholder() {
        let asText = Prefs.requireNotes ? "notes (required)" : "notes"
        if let placeholder = noteField.placeholderAttributedString {
            let attributes = placeholder.attributes(at: 0, effectiveRange: nil)
            noteField.placeholderAttributedString = NSAttributedString(string: asText, attributes: attributes)
        } else if noteField.placeholderString != nil {
            noteField.placeholderString = asText
        }
    }
    
    func reset() {
        noteField.stringValue = ""
        if projectField.stringValue.isEmpty {
            taskField.stringValue = ""
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        projectField.nextKeyView = taskField
        taskField.nextKeyView = noteField
        noteField.nextKeyView = projectField
        
        setUpNewSessionPrompt(
            scheduler: scheduler,
            onNewSession: {
                self.hooks?.forceReschedule()
                self.closeWindowAsync()
            },
            onKeepSesion: {
                self.grabFocusEvenIfHasSheet()
            })

        func scheduleUpdateHeaderText() {
            scheduler.schedule("per-minute update header", after: 60) {
                self.updateHeaderText()
                scheduleUpdateHeaderText()
            }
        }
        scheduleUpdateHeaderText()
        
        goals.reset()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        noteField.stringValue = ""
        setNotesPlaceholder()
        setUpSnoozeButton()
        updateHeaderText()
        
        if let window = view.window {
            let currentFrame = window.frame
            let topLeft = NSPoint(x: currentFrame.minX, y: currentFrame.maxY)
            window.setFrame(
                NSRect(origin: topLeft, size: view.fittingSize),
                display: true)
        }
        
        grabFocus()
    }
    
    private func setUpSnoozeButton(untilTomorrowSettings: (hhMm: HoursAndMinutes, includeWeekends: Bool)? = nil) {
        if let activeSpinner = snoozeOptionsUpdateSpinner {
            activeSpinner.removeFromSuperview()
            snoozeOptionsUpdateSpinner = nil
        }
        snoozeButton.isEnabled = true
        if let alreadySnoozedUntil = hooks?.snoozedUntil {
            snoozeButton.attributedTitle = NSAttributedString(
                string: "Snoozing until \(TimeUtil.formatSuccinctly(date: alreadySnoozedUntil))",
                attributes: [.foregroundColor: NSColor.red])
            snoozeExtraOptions.isEnabled = false
            scheduler.schedule("Snooze options refresh", at: alreadySnoozedUntil, updateSnoozeButton)
        } else {
            // Set up the snooze button to be now + 10 minutes, rounded up to the
            // closest half-hour.
            // The 10 minutes is so that if it's currently 2:29:59, you won't be annoyed with a "snooze until 2:30" button.
            let defaultSnoozeDate = TimeUtil.roundUp(scheduler.now, bufferedByMinute: 10, toClosestMinute: 30)

            snoozeButton.title = "Snooze until \(TimeUtil.formatSuccinctly(date: defaultSnoozeDate))   " // extra space for the pulldown option
            self.snoozeUntil = Date(timeIntervalSince1970: defaultSnoozeDate.timeIntervalSince1970)
            let refreshOptionsAt = defaultSnoozeDate.addingTimeInterval(-300)
            snoozeExtraOptions.isEnabled = true
            for menuItem in snoozeExtraOptions.itemArray {
                let plusMinutes = menuItem.tag
                if plusMinutes > 0 {
                    let optionSnoozeDate = defaultSnoozeDate.addingTimeInterval(TimeInterval(plusMinutes) * 60.0)
                    menuItem.title = TimeUtil.formatSuccinctly(date: optionSnoozeDate)
                    menuItem.representedObject = optionSnoozeDate
                }
            }
            
            let nextSessionHhMm = untilTomorrowSettings?.hhMm ?? Prefs.dayStartTime
            let nextSessionWeekends = untilTomorrowSettings?.includeWeekends ?? Prefs.daysIncludeWeekends
            let latestDate = snoozeExtraOptions.itemArray
                .filter({$0.tag > 0})
                .compactMap({$0.representedObject as? Date})
                .last
                ?? defaultSnoozeDate
            let nextSessionDate = nextSessionHhMm.map {hh, mm in
                TimeUtil.dateForTime(.next, hh: hh, mm: mm, excludeWeekends: !nextSessionWeekends, assumingNow: latestDate)}
            snoozeUntilTomorrow.title = TimeUtil.formatSuccinctly(date: nextSessionDate)
            snoozeUntilTomorrow.representedObject = nextSessionDate
            
            scheduler.schedule("Snooze options refresh", at: refreshOptionsAt, updateSnoozeButton)
        }
    }
    
    private func updateSnoozeButton() {
        if let snoozeParent = snoozeButton.superview {
            // Disable the snooze button, and set a spinner
            snoozeButton.isEnabled = false
            snoozeExtraOptions.isEnabled = false
            if snoozeOptionsUpdateSpinner == nil {
                let newSpinner = NSProgressIndicator()
                snoozeOptionsUpdateSpinner = newSpinner
                newSpinner.useAutoLayout()
                snoozeParent.addSubview(newSpinner)
                newSpinner.startAnimation(self)
                newSpinner.isIndeterminate = true
                newSpinner.style = .spinning
                newSpinner.centerYAnchor.constraint(equalTo: snoozeButton.centerYAnchor).isActive = true
                newSpinner.centerXAnchor.constraint(equalTo: snoozeButton.centerXAnchor).isActive = true
                newSpinner.heightAnchor.constraint(equalTo: snoozeButton.heightAnchor).isActive = true
            }
            // Wait a second, and then update the options and set a new spinner
            scheduler.schedule("Set the new snooze options", after: 1) {
                self.setUpSnoozeButton()
            }
        }
    }
    
    private func updateHeaderText() {
        let lastEntryDate = model.lastEntryDate
        headerText.stringValue = headerText.placeholderString!.replacingBracketedPlaceholders(with: [
            "TIME": TimeUtil.formatSuccinctly(date: lastEntryDate),
            "DURATION": TimeUtil.daysHoursMinutes(for: scheduler.timeInterval(since: lastEntryDate))
        ])
    }
    
    @IBAction private func snoozeButtonPressed(_ sender: NSControl) {
        if let _ = hooks?.snoozedUntil {
            let unsnoozePopover = NSPopover()
            unsnoozePopover.behavior = .transient
            
            let unsnoozeViewController = NSViewController()
            let button = ButtonWithClosure(label: "Unsnooze") {_ in
                self.hooks?.unSnooze()
                self.setUpSnoozeButton()
                unsnoozePopover.close()
            }
            button.font = snoozeButton.font
            button.focusRingType = .none
            button.bezelStyle = .roundRect
            button.bezelColor = NSColor.controlAccentColor
            button.contentTintColor = NSColor.controlAccentColor
            
            unsnoozeViewController.view = button
            let buttonSize = button.intrinsicContentSize
            unsnoozePopover.contentSize = NSSize(width: buttonSize.width * 1.4, height: buttonSize.height * 1.5)
            
            unsnoozePopover.contentViewController = unsnoozeViewController
            unsnoozePopover.show(relativeTo: snoozeButton.bounds, of: snoozeButton, preferredEdge: .minY)
        } else {
            snooze(until: snoozeUntil)
        }
    }
    
    @IBAction func snoozeExtraOptionsSelected(_ sender: NSPopUpButton) {
        snooze(until: sender.selectedItem?.representedObject)
    }
    
    private func snooze(until: Any?) {
        if let date = until as? Date {
            hooks?.snooze(until: date)
        } else {
            wdlog(.error, "date not set up (was %{public}@)", until.debugDescription)
        }
    }
    
    @IBAction func handleSkipSessionButton(_ sender: Any) {
        if let window = view.window {
            let confirm = ConfirmViewController()
            let showConfirmation = confirm.prepareToAttach(to: window)
            let duration = TimeUtil.daysHoursMinutes(
                for: scheduler.timeInterval(since: model.lastEntryDate))
            confirm.header = "Skip this session?"
            confirm.detail = """
            If you skip this session, the last \(duration) will not be recorded.

            You cannot undo this action.

            If you took a break, consider recording it as such. For example:
            break / social media / looking at friends' pictures
            """
            confirm.proceedButtonText = "Skip session"
            confirm.cancelButtonText = "Don't skip"
            confirm.onProceed = skipSession
            showConfirmation()
        } else {
            wdlog(.warn, "can't find window to post confirmation alert in skipSession. Will proceed with skipping session.")
            skipSession()
        }
    }
    
    private func skipSession() {
        model.setLastEntryDateToNow()
        self.closeWindowAsync()
    }
    
    fileprivate func openFind() {
        projectTaskFinder.isHidden = false
        view.layoutSubtreeIfNeeded()
        resizeWindowToFit()
        view.window?.makeFirstResponder(projectTaskFinder)
    }
    
    @IBAction func closeFind(_ sender: Any) {
        projectTaskFinder.isHidden = true
        resizeWindowToFit()
        grabFocusNow() // grab the project, task, or note field — whatever's open
    }
    
    private func resizeWindowToFit() {
        guard let window = view.window else {
            wdlog(.warn, "Couldn't find PTN window to resize")
            return
        }
        let currFrame = window.frame
        let requiredSize = view.fittingSize
        let deltaYFromResize = currFrame.height - requiredSize.height
        window.setFrame(
            NSRect(
                x: currFrame.minX,
                y: currFrame.minY + deltaYFromResize,
                width: currFrame.width,
                height: requiredSize.height),
            display: true)
    }
    
    @IBAction func preferenceButtonPressed(_ sender: NSButton) {
        if let viewWindow = view.window {
            let prefsWindow = NSWindow(contentRect: viewWindow.frame, styleMask: [.titled], backing: .buffered, defer: true)
            prefsWindow.backgroundColor = NSColor.windowBackgroundColor
            
            let prefsViewController = PrefsViewController(nibName: "PrefsViewController", bundle: nil)
            prefsViewController.setSize(width: viewWindow.frame.width, minHeight: viewWindow.frame.height)
            prefsWindow.contentViewController = prefsViewController // also loads the controller
            if let hooks = hooks {
                prefsViewController.ptnScheduleChanged = hooks.forceReschedule
            }
            viewWindow.beginSheet(prefsWindow, completionHandler: {reason in
                if reason == .stop {
                    NSApp.terminate(self)
                }
                if reason == PrefsViewController.SHOW_TUTORIAL {
                    self.showTutorial(forVersion: PtnViewController.CURRENT_TUTORIAL_VERSION)
                }
                if reason == PrefsViewController.CLOSE_PTN {
                    self.closeWindowAsync()
                }
                self.setNotesPlaceholder()
                self.setUpSnoozeButton(untilTomorrowSettings: prefsViewController.snoozeUntilTomorrowInfo)
            })
        }
    }

    func grabFocus() {
        if (view.window?.sheets ?? []).isEmpty {
            grabFocusEvenIfHasSheet()
        }
    }
    
    private func grabFocusEvenIfHasSheet() {
        perform(#selector(grabFocusNow), with: nil, afterDelay: TimeInterval.zero, inModes: [RunLoop.Mode.common])
    }

    /// Only intended for unit tests. In prod code, prefer `grabFocus`.
    @objc func grabFocusNow() {
        var firstResponder = noteField
        if projectField.stringValue.isEmpty {
            firstResponder = projectField
        } else if taskField.stringValue.isEmpty {
            firstResponder = taskField
        }
        if firstResponder != nil {
            view.window?.makeFirstResponder(firstResponder)
        }
    }
    
    func projectOrTaskAction(_ sender: AutoCompletingField) {
        if let nextView = sender.nextValidKeyView {
            view.window?.makeFirstResponder(nextView)
        }
    }
    
    @IBAction func notesFieldAction(_ sender: NSTextField) {
        let project = projectField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = taskField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var allowEntry = true
        if project.isEmpty {
            projectField.flashTextField()
            allowEntry = false
        }
        if task.isEmpty {
            taskField.flashTextField()
            allowEntry = false
        }
        if notes.isEmpty && Prefs.requireNotes {
            noteField.flashTextField()
            allowEntry = false
        }
        if allowEntry {
            model.addEntryNow(
                project: project,
                task: task,
                notes: notes,
                callback: {
                    self.hooks?.forceReschedule()
                    self.closeWindowAsync()
                }
            )
        }
    }
    
    override func viewWillDisappear() {
        if let window = view.window {
            for sheet in window.sheets {
                window.endSheet(sheet, returnCode: .abort)
            }
        }
        super.viewWillDisappear()
    }
    
    func showTutorial(forVersion prefsVersion: Int) {
        let tutorial = TutorialViewController(nibName: "TutorialViewController", bundle: nil)
        let prefsView: (NSView, [LifecycleHandler])?
        if prefsVersion < 0 {
            let optionsGrid = NSGridView(numberOfColumns: 3, rows: 0)
            // Header
            optionsGrid.addRow(with: [
                NSTextField(wrappingLabelWithString:
                                "Since this is your first time running Whatdid, "
                                + "would you like to:")
            ])
            optionsGrid.row(at: 0).mergeCells(in: NSMakeRange(0, 3))
            // Launch-at-login row
            Prefs.launchAtLogin = true
            let launchAtLoginCheckbox = InitialPrefsCheckbox(pref: Prefs.$launchAtLogin)
            optionsGrid.addRow(with: [
                NSTextField(labelWithString: "➤ "),
                NSTextField(wrappingLabelWithString: "Launch Whatdid at login?"),
                launchAtLoginCheckbox,
            ])
            // Analytics row
            Prefs.analyticsEnabled = true
            let privacyButton = HrefButton(title: "privacy policy", target: nil, action: nil)
            privacyButton.toolTip = UsageTracking.PRIVACY_URL
            privacyButton.controlSize = .small
            let allowAnalytics = InitialPrefsCheckbox(pref: Prefs.$analyticsEnabled)
            optionsGrid.addRow(with: [
                NSTextField(labelWithString: "➤ "),
                NSTextField(wrappingLabelWithString: "Send anonymized usage data?"),
                NSStackView(orientation: .horizontal, allowAnalytics, privacyButton),
            ])
            // Shortcut recorder. For some reason, the recorder widget doesn't like to be in
            // a cell by itself; we need to wrap it in a view first.
            let recorder = KeyboardShortcuts.RecorderCocoa(for: .grabFocus)
            let boundsAdjuster = NSView()
            boundsAdjuster.addSubview(recorder)
            boundsAdjuster.anchorAllSides(to: recorder)
            optionsGrid.addRow(with: [
                NSTextField(labelWithString: "➤ "),
                NSTextField(wrappingLabelWithString: "Make a shortcut to open this window?"),
                boundsAdjuster,
            ])
            // Put them together
            prefsView = (optionsGrid, [allowAnalytics, launchAtLoginCheckbox])
        } else {
            prefsView = nil
        }
        tutorial.add(
            .init(
                title: "\"Whatdid I do all day?!\"",
                text: [
                    "This window will pop up every so often to ask you what you've been up to.",
                    "At the end of the day, it'll aggregate all of the check-ins and let you see all you've accomplished."
                ],
                pointingTo: view,
                atEdge: .minX,
                extraView: prefsView?.0,
                lifecycleHandlers: prefsView?.1 ?? []),
            .init(
                title: "Projects",
                text: [
                    "Enter the project you've been working on.",
                    "A good general rule is that a project will take 1-2 months.",
                    "This is most useful when looking at reports over months or a year, to see what you accomplished at a high level.",
                    "This can also be a catch-all, like \"general office work\" or even \"break\"."
                ],
                pointingTo: projectField,
                atEdge: .minY),
            .init(
                title: "Tasks",
                text: [
                    "A typical task takes 1-5 days.",
                    "In daily or weekly views, you can use this to see what tasks took up each project's time.",
                    "For a project like \"general office work\" a task might be \"email\" or \"scheduling my day\"."
                ],
                pointingTo: taskField,
                atEdge: .minY),
            .init(
                title: "Notes",
                text: [
                    "You can optionally enter notes about your work on this task.",
                    "This is most useful when looking at a daily report, to see the progression of your day."
                ],
                pointingTo: noteField,
                atEdge: .minY),
            .init(
                title: "Snooze",
                text: [
                    "You can pause notifications for a while, or even until tomorrow.",
                    "While Whatdid is snoozing, its timer is still going. When you check in after the snooze, "
                        + "it'll include the snooze time.",
                    "This is a useful way to prevent interruptions during meetings."
                ],
                pointingTo: snoozeButton,
                atEdge: .minX),
            .init(
                title: "Settings",
                text: [
                    "Configure settings like popup frequency or keyboard shortcuts.",
                    "You can also use this to quit Whatdid.",
                    "There are also links to drop us feedback!"
                ],
                pointingTo: prefsButton,
                atEdge: .minY),
            .init(
                title: "System icon",
                text: [
                    "Use the system icon to open up the window whenever you want.",
                    "You can option-click it to see a report of what you've done so far today.",
                    "I hope you enjoy Whatdid!"
                ],
                pointingTo: AppDelegate.instance.mainMenu.statusItem.button!,
                atEdge: .minY,
                highlight: .exactSize)
        )
        tutorial.show()
    }
    
    class InitialPrefsCheckbox: ButtonWithClosure, LifecycleHandler {
        var pref: PrefsListeners<Bool>?
        private var listenHandler: PrefsListenHandler? = nil
        
        convenience init(pref: PrefsListeners<Bool>) {
            self.init(checkboxWithTitle: "", target: nil, action: nil)
            onPress {button in
                self.pref?.setValue(to: button.state == .on)
            }
            self.pref = pref
        }
        
        func onAppear() {
            onDisappear()
            listenHandler = pref?.addListener {launchAtLogin in
                self.state = launchAtLogin ? .on : .off
            }
        }
        
        func onDisappear() {
            if let oldHandler = listenHandler {
                oldHandler.unregister()
                listenHandler = nil
            }
        }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.characters?.lowercased() == "f" {
            print("FOUND")
            return true
        }
        return false
    }
}

class PtnTopLevelStackView: NSStackView {
    fileprivate var parent: PtnViewController?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) {
            return true
        }
        if event.characters?.lowercased() == "f", let parent = parent {
            parent.openFind()
            return true
        }
        return false
    }
}

protocol PtnViewDelegate {
    func forceReschedule()
    func snooze(until date: Date)
    func unSnooze()
    var snoozedUntil: Date? { get }
}
