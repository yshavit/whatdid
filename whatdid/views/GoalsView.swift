// whatdid?

import Cocoa
import WhatdidLauncher

class GoalsView: WdView, NSAccessibilityGroup {
    private static let new_marker = "🔸"
    private static let new_goal_grace_time = TimeInterval(60 * 60) // one hour
    private static let horizontal_spacing: CGFloat = 3
    private static let small_control_font = NSFont.controlContentFont(ofSize: NSFont.systemFontSize(for: .small))
    
    private let topStack = NSStackView(orientation: .vertical)
    private let addButton = ExpandableTextField()

    private var oldWidth: CGFloat?

    #if TARGET_INTERFACE_BUILDER
    private static var model: GoalsViewModel = DummyModel()
    #else
    private static var model: GoalsViewModel {
        AppDelegate.instance.model
    }
    #endif
    
    override func wdViewInit() {
        addSubview(topStack)
        topStack.anchorAllSides(to: self)
        topStack.alignment = .leading
        topStack.spacing = GoalsView.horizontal_spacing
        addButton.controlSize = .small
        addButton.font = GoalsView.small_control_font
        addButton.expandCollapseHook = self.handleAddButtonExpansionOrCollapse
        addButton.goalHook = self.addGoalFrom(text:)
        layOutElements()
        setAccessibilityRole(.group)
        setAccessibilityLabel("Goals for today")
    }
    
    func reset() {
        layOutElements()
    }
    
    override func initializeInterfaceBuilder() {
        addGoalFrom(text: "goal 1")
        addGoalFrom(text: "goal 2")
    }
    
    func addGoalView(_ goal: Model.GoalDto) {
        add(view: GoalsView.from(goal))
    }
    
    private func addGoalFrom(text: String) {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stripped.isEmpty {
            addGoalView(GoalsView.model.createNewGoal(goal: text))
        }
    }
    
    override var frame: NSRect {
        didSet {
            if frame.width != oldWidth {
                layOutElements()
                oldWidth = frame.width
            }
        }
    }
    
    private func handleAddButtonExpansionOrCollapse() {
        let originalFirstResponder = window?.firstResponder
        let originalSelection: NSRange?
        if let originalEditor = addButton.currentEditor, originalEditor == originalFirstResponder {
            originalSelection = originalEditor.selectedRange
        } else {
            originalSelection = nil
        }
        if currentRow.arrangedSubviews.count == 1 {
            // The add/collapse button is all by itself. It may have been collapsed, so check to see
            // if it + a spacer can fit on the row above.
            if topStack.arrangedSubviews.count > 1 {
                let penultimateRow = topStack.arrangedSubviews[topStack.arrangedSubviews.count - 2] as! NSStackView
                let spacer = Spacer()
                if width(of: penultimateRow.arrangedSubviews) + width(of: spacer, addButton) <= frame.width {
                    removeAddButton()
                    topStack.removeArrangedSubview(currentRow)
                    currentRow.addArrangedSubview(spacer)
                    currentRow.addArrangedSubview(addButton)
                    topStack.layoutSubtreeIfNeeded()
                }
            }
        } else if width(of: currentRow.arrangedSubviews) > frame.width {
            removeAddButton()
            createRow()
            currentRow.addArrangedSubview(addButton)
            topStack.layoutSubtreeIfNeeded()
        }
        if let originalSelection = originalSelection, let window = window, window.firstResponder != originalFirstResponder {
            addButton.makeFirstResponder(for: window)
            addButton.currentEditor?.selectedRange = originalSelection
        }
    }
    
    private func layOutElements() {
        // clear everything out
        for child in topStack.arrangedSubviews {
            if let hstack = child as? NSStackView {
                hstack.subviews.forEach { $0.removeFromSuperview() }
            }
            child.removeFromSuperview()
        }
        
        // set up our first hstack, and then start looping
        createRow()
        let sectionLabel = NSTextField(labelWithAttributedString: NSAttributedString(string: "Goals", attributes: [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: GoalsView.small_control_font
        ]))
        sectionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        currentRow.addArrangedSubview(sectionLabel)
        currentRow.addArrangedSubview(Spacer())
        currentRow.addArrangedSubview(addButton)
        
        let goals = GoalsView.model.listGoalsForCurrentSession()
        goals.forEach(addGoalView(_:))
    }
    
    private var currentRowWidth: CGFloat {
        currentRow.arrangedSubviews.map({$0.intrinsicContentSize.width}).reduce(0, +)
    }
    
    private func createRow() {
        let stack = NSStackView(orientation: .horizontal)
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.spacing = GoalsView.horizontal_spacing
        topStack.addArrangedSubview(stack)
        stack.leadingAnchor.constraint(equalTo: topStack.leadingAnchor).isActive = true
        stack.trailingAnchor.constraint(equalTo: topStack.trailingAnchor).isActive = true
    }
    
    private var currentRow: NSStackView {
        topStack.arrangedSubviews.last as! NSStackView
    }
    
    private func removeAddButton() {
        currentRow.removeArrangedSubview(addButton)
        if let addButtonSpacer = currentRow.arrangedSubviews.last as? Spacer {
            currentRow.removeArrangedSubview(addButtonSpacer)
        }
    }
    
    private func add(view: NSView) {
        // Three possibilities:
        // 1) The current element fits on the row as-is
        //    (that is, before the spacer-and-add which are at the end of the row)
        // 2) The current element fits on the row, but we have to bump the add button down
        // 3) The current element can't fit on the row even without the add button.
        //    In this case, both the element and the add button get bumped.
        
        let spacer = Spacer()
        if currentRowWidth + width(of: view, spacer) <= frame.width {
            // Scenario 1. Insert [view, spacer] before the addButton. Note that we insert them in reverse order, since we're keeping
            // the same index.
            let insertAt = currentRow.arrangedSubviews.endIndex - 1
            currentRow.insertArrangedSubview(spacer, at: insertAt)
            currentRow.insertArrangedSubview(view, at: insertAt)
        } else {
            // No matter what, the add button is coming off, and its spacer if there is one
            removeAddButton()
            if currentRowWidth + width(of: view) <= frame.width {
                // Scenario 2: add the new element and its spacer, and then the add button on a new row
                currentRow.addArrangedSubview(spacer)
                currentRow.addArrangedSubview(view)
                createRow()
                currentRow.addArrangedSubview(addButton)
            } else {
                // Scenario 3: Add the new element to a new row. Then add the button to this new row if we
                // can, or else to a new-new row.
                createRow()
                currentRow.addArrangedSubview(view)
                if currentRowWidth + width(of: spacer, addButton) <= frame.width {
                    currentRow.addArrangedSubview(spacer)
                } else {
                    createRow()
                }
                currentRow.addArrangedSubview(addButton)
            }
        }
    }
    
    private func width(of views: NSView...) -> CGFloat {
        return width(of: views)
    }
    
    private func width(of views: [NSView]) -> CGFloat {
        let viewsWidth = views.map({$0.intrinsicContentSize.width}).reduce(0, +)
        // We have views.count - 1 fence posts, and each has 2x the spacing (1x on each side of the post)
        let spacingWidth = CGFloat(views.count - 1) * currentRow.spacing * 2.0
        let prefixWidth = currentRow.arrangedSubviews.isEmpty ? 0 : currentRow.spacing
        return viewsWidth + spacingWidth + prefixWidth
    }
    
    static func from(_ goal: Model.GoalDto) -> NSView {
        let checkbox = ButtonWithClosure(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.controlSize = .small
        checkbox.state = goal.isCompleted ? .on : .off
        let addedLate = goal.created.timeIntervalSince(goal.sessionStart) > new_goal_grace_time
        checkbox.attributedTitle = goalTitle(string: goal.goal, addedLate: addedLate)
        checkbox.attributedAlternateTitle = goalTitle(string: goal.goal, addedLate: addedLate, attributes: [
            .obliqueness: 0.15,
            .foregroundColor: NSColor.controlAccentColor
        ])
        if addedLate {
            checkbox.toolTip = "\(new_marker) – You added this tip later in the day."
        }
        checkbox.onPress {button in
            var toSave = goal
            toSave.completed = (button.state == .on) ? DefaultScheduler.instance.now : nil
            self.model.save(goal: toSave)
        }
        return checkbox
    }
    
    private static func goalTitle(string: String, addedLate: Bool, attributes: [NSAttributedString.Key:Any]? = nil) -> NSAttributedString {
        guard addedLate else {
            return NSAttributedString(string: string, attributes: attributes)
        }
        var newAttributes = attributes ?? [:]
        /// As far as I can tell, `.supersript`
        newAttributes[.superscript] = 1
        newAttributes[.font] = NSFont.controlContentFont(ofSize: NSFont.systemFontSize(for: .small) * 0.6)
        let builder = NSMutableAttributedString()
        builder.append(NSAttributedString(string: string + " ", attributes: attributes))
        builder.append(NSAttributedString(string: GoalsView.new_marker, attributes: newAttributes))
        return builder
    }
    
    private class Spacer: NSTextField {
        private static let label = NSAttributedString(string: "┃", attributes: [
            .foregroundColor: NSColor.separatorColor,
            .font: GoalsView.small_control_font
        ])
        
        convenience init() {
            self.init(labelWithAttributedString: Spacer.label)
        }
    }
}

fileprivate protocol GoalsViewModel {
    func createNewGoal(goal text: String) -> Model.GoalDto
    func listGoalsForCurrentSession() -> [Model.GoalDto]
    func save(goal: Model.GoalDto)
}

#if TARGET_INTERFACE_BUILDER
class DummyModel: GoalsViewModel {
    let now = Date()
    var goals = [Model.GoalDto]()
    
    func createNewGoal(goal text: String) -> Model.GoalDto {
        let id = goals.count
        let url = URL(string: "whatdid-ib://model/\(id)")!
        let goal = Model.GoalDto(
            id: url,
            goal: text,
            created: now,
            sessionStart: now,
            orderWithinSession: id)
        goals.append(goal)
        return goal
    }
    
    func listGoalsForCurrentSession() -> [Model.GoalDto] {
        return goals
    }
    
    func save(goal: Model.GoalDto) {
        guard let goalIdInt = Int(goal.id.path) else {
            wdlog(.warn, "couldn't parse id from URL path: %@", goal.id.absoluteString)
            return
        }
        goals[goalIdInt] = goal
    }
    
    
}
#else
extension Model: GoalsViewModel {
    // all methods already implemented
}
#endif
