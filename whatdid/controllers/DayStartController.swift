// whatdid?

import Cocoa

class DayStartController: NSViewController, NSTextFieldDelegate, CloseConfirmer {
    
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var goals: NSStackView!
    @IBOutlet var goalPrototype: NSStackView!
    private var goalTemplate: Data!
    private var saveButtonOriginalText: String?
    /// tri-value bool; nil means "prompt"
    private var saveGoalsOnExit: Bool?
    
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
        setSaveButtonText()
        setUpNewSessionPrompt(
            scheduler: scheduler,
            onNewSession: {},
            onKeepSesion: {})
    }
    
    override func viewWillDisappear() {
        let model = AppDelegate.instance.model
        let _ = model.createNewSession()
        if let shouldSave = saveGoalsOnExit {
            if shouldSave {
                goalTexts.forEach { let _ = model.createNewGoal(goal: $0) }
            }
        } else {
            NSLog("saveGoalsOnExit was nil; not saving goals. This is unexpected.")
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
        NSAnimationContext.runAnimationGroup(
            {context in
                context.allowsImplicitAnimation = true
                context.duration = 2
                goals.addArrangedSubview(field)
            },
            completionHandler: field.grabFocus)
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
    
    private func setSaveButtonText() {
        if goalEntries.contains(where: {!$0.goalText.isEmpty}) {
            saveButton.title = saveButtonOriginalText ?? "Save"
        } else {
            saveButton.title = "Dismiss without setting goals"
        }
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
                NSAnimationContext.runAnimationGroup(
                    {context in
                        context.allowsImplicitAnimation = true
                        context.duration = 0.1
                        self.alphaValue = 0
                    },
                    completionHandler: {
                        NSAnimationContext.runAnimationGroup {context in
                            context.allowsImplicitAnimation = true
                            context.duration = 0.4
                            let windowBeforeRemove = self.window
                            self.removeFromSuperview()
                            if let windowBeforeRemove = windowBeforeRemove, let content = windowBeforeRemove.contentView {
                                windowBeforeRemove.setContentSize(content.fittingSize)
                            }
                            self.owner.setSaveButtonText()
                        }
                    }
                )
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
