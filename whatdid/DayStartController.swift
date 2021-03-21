// whatdid?

import Cocoa

class DayStartController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var goals: NSStackView!
    @IBOutlet var goalPrototype: NSStackView!
    private var goalTemplate: Data!
    private var onClose: (() -> Void)?
    private var saveButtonOriginalText: String?
    
    var scheduler: Scheduler = DefaultScheduler.instance
    
    convenience init(onClose: @escaping () -> Void) {
        self.init()
        self.onClose = onClose
    }
    
    private var goalEntries: [GoalEntryField] {
        goals.subviews.compactMap({$0 as? GoalEntryField})
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        goals.subviews.forEach { $0.removeFromSuperview() }
        addGoalField()
        saveButtonOriginalText = saveButton.title
    }
    
    override func viewDidAppear() {
        setSaveButtonText()
        setUpNewSessionPrompt(
            scheduler: scheduler,
            onNewSession: {},
            onKeepSesion: {})
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
        let model = AppDelegate.instance.model
        let _ = model.createNewSession()
        goalEntries.map({$0.goalText}).forEach {goal in
            if !goal.isEmpty {
                let _ = model.createNewGoal(goal: goal)
            }
        }
        onClose?()
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
