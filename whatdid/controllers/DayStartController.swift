// whatdid?

import Cocoa

class DayStartController: NSViewController, NSTextFieldDelegate, CloseConfirmer {
    
    @IBOutlet var saveButton: NSButton!
    @IBOutlet weak var saveButtonTip: NSTextField!
    @IBOutlet var goals: NSStackView!
    private var saveButtonOriginalText: String?
    /// tri-value bool; nil means "prompt"
    private var saveGoalsOnExit: Bool?
    private var commandStateListener: Any?
    
    var scheduler: Scheduler = DefaultScheduler.instance
    
    private var goalEntries: [GoalEntryField] {
        goals.subviews.compactMap({$0 as? GoalEntryField})
    }
    
    private var goalTexts: [String] {
        goalEntries.compactMap {g in
            let text = g.goalText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        goals.subviews.forEach { $0.removeFromSuperview() }
        addGoalField()
        saveButtonOriginalText = saveButton.title
    }
    
    override func viewWillAppear() {
        // Listen for modifier flags, and set the save button's key-equivalent to the enter key iff the Command button is pressed
        commandStateListener = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {event in
            let commandKeyDown = (event.modifierFlags.contains(.command))
            self.saveButton.keyEquivalent = ((commandKeyDown && self.hasGoalsToSave) ? "\r" : "")
            return event
        }
        setSaveButtonText()
        setUpNewSessionPrompt(
            scheduler: scheduler,
            onNewSession: {},
            onKeepSesion: {})
    }
    
    override func viewWillDisappear() {
        if let listenerToRemove = commandStateListener {
            NSEvent.removeMonitor(listenerToRemove)
            commandStateListener = nil
        }
        let model = AppDelegate.instance.model
        let _ = model.createNewSession()
        if let shouldSave = saveGoalsOnExit {
            if shouldSave {
                goalTexts.forEach { let _ = model.createNewGoal(goal: $0) }
            }
        } else if !goalTexts.isEmpty {
            wdlog(.warn, "saveGoalsOnExit was nil, but there were goal texts; not saving goals. This is unexpected.")
        }
        // We have to clear the entries before closing, or else the "save goals?" alert will show
        self.goalEntries.forEach({$0.removeGoal()})
    }
    
    func requestClose(on window: NSWindow) -> Bool {
        if saveGoalsOnExit == nil {
            let goalsCount = goalTexts.count
            // don't prompt if there are no goals; this isn't a destructive action (they can always add goals later),
            // so just let it go.
            guard goalsCount > 0 else {
                return true
            }
            let confirm = NSAlert()
            confirm.alertStyle = .warning
            confirm.messageText = "Save \(goalsCount.pluralize("goal", "goals", showValue: false))?"
            confirm.informativeText = "You entered \(goalsCount.pluralize("goal", "goals"))."
            confirm.addButton(withTitle: "Save")
            confirm.addButton(withTitle: "Don't Save")
            confirm.beginSheetModal(for: window) {response in
                self.saveGoalsOnExit = (response == .alertFirstButtonReturn)
                self.closeWindowAsync()
            }
            return false
        } else {
            return true
        }
    }
    
    private func addGoalField() {
        let field = GoalEntryField(owner: self)
        AnimationHelper.animate(
            duration: 2,
            change: {
                goals.addArrangedSubview(field)
            },
            onComplete: field.grabFocus)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if let event = NSApp.currentEvent {
            let isKeyDown = (event.type == .keyDown)
            let isEnterKey = (event.keyCode == 36)
            let commandKeyPressed = event.modifierFlags.contains(.command)
            if isKeyDown && isEnterKey && commandKeyPressed && (saveButton.keyEquivalent == "\r") {
                saveButton(self)
                return true
            }
        }
        return false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        setSaveButtonText()
    }
    
    @IBAction func saveButton(_ sender: Any) {
        saveGoalsOnExit = true
        closeWindowAsync()
    }
    
    private func goalFinishedTextEditing() {
        let lastEntryIsEmpty = goalEntries.last?.goalText.isEmpty ?? false
        if !lastEntryIsEmpty {
            addGoalField()
        }
    }
    
    private func canRemove(_ entry: GoalEntryField) -> Bool {
        return goalEntries.last != entry
    }
    
    private var hasGoalsToSave: Bool {
        goalEntries.contains(where: {!$0.goalText.isEmpty})
    }
    
    private func setSaveButtonText() {
        let showSaveText = hasGoalsToSave
        if showSaveText {
            saveButton.title = saveButtonOriginalText ?? "Save"
        } else {
            saveButton.title = "Dismiss without setting goals"
            saveButton.keyEquivalent = ""
        }
        saveButtonTip.isHidden = !showSaveText
    }
    
    private class GoalEntryField: NSStackView {
        private var owner: DayStartController!
        private var field: NSTextField!
        
        var goalText: String {
            return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        convenience init(owner: DayStartController) {
            self.init(orientation: .horizontal)
            self.alignment = .centerY
            self.owner = owner
            
            field = NSTextField(string: "")
            field.placeholderString = "Enter a goal"
            field.target = self
            field.action = #selector(self.finishedTextEditing)
            field.delegate = owner
            self.addArrangedSubview(field)
            
            let rmButton: NSButton
            if let trashIcon = NSImage(named: NSImage.touchBarDeleteTemplateName) {
                rmButton = NSButton(image: trashIcon, target: nil, action: nil)
                rmButton.isBordered = false
            } else {
                rmButton = NSButton(title: "✗⃝", target: nil, action: nil)
                rmButton.bezelStyle = .smallSquare
            }
            rmButton.target = self
            rmButton.action = #selector(self.removeGoal)
            self.addArrangedSubview(rmButton)
        }
        
        @objc func removeGoal() {
            if owner.canRemove(self) {
                AnimationHelper.animate(
                    duration: 0.1,
                    change: {
                        self.alphaValue = 0
                    },
                    onComplete: {
                        AnimationHelper.animate(duration: 0.4) {
                            let windowBeforeRemove = self.window
                            self.removeFromSuperview()
                            if let windowBeforeRemove = windowBeforeRemove, let content = windowBeforeRemove.contentView {
                                windowBeforeRemove.setContentSize(content.fittingSize)
                            }
                            self.owner.setSaveButtonText()
                        }
                    })
            } else {
                field.stringValue = ""
                owner.setSaveButtonText()
            }
        }
        
        @objc private func finishedTextEditing() {
            if goalText.isEmpty {
                removeGoal()
            } else {
                owner.goalFinishedTextEditing()
            }
        }
        
        func grabFocus() {
            window?.makeFirstResponder(field)
        }
    }
}
