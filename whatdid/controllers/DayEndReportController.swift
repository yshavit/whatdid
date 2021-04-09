// whatdid?

import Cocoa

class DayEndReportController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        goalsSummaryGroup.setAccessibilityElement(true)
        goalsSummaryGroup.setAccessibilityEnabled(true)
        goalsSummaryGroup.setAccessibilityRole(.group)
        goalsSummaryGroup.setAccessibilityLabel("Today's Goals")
    }
    
    @IBOutlet var widthFitsOnScreen: NSLayoutConstraint!
    @IBOutlet weak var maxViewHeight: NSLayoutConstraint!
    @IBOutlet weak var goalsSummaryGroup: NSView!
    @IBOutlet weak var goalsSummaryStack: NSStackView!
    @IBOutlet weak var projectsScroll: NSScrollView!
    @IBOutlet weak var projectsScrollHeight: NSLayoutConstraint!
    @IBOutlet weak var projectsContainer: NSStackView!
    @IBOutlet weak var entryStartDatePicker: NSDatePicker!
    
    var scheduler: Scheduler = DefaultScheduler.instance
    
    override func awakeFromNib() {
        if #available(OSX 10.15.4, *) {
            entryStartDatePicker.presentsCalendarOverlay = true
        }
    }
    
    private static func createDisclosure(state: NSButton.StateValue)  -> ButtonWithClosure {
        let result = ButtonWithClosure()
        result.state = state
        result.setButtonType(.pushOnPushOff)
        result.bezelStyle = .disclosure
        result.imagePosition = .imageOnly
        return result
    }
    
    func prepareForViewing() {
        // Set the window's max height, using the golden ratio.
        if let screenHeight = view.window?.screen?.frame.height {
            maxViewHeight.constant = screenHeight * 0.61802903
            NSLog("set max height to %.1f (screen height is %.1f)", maxViewHeight.constant, screenHeight)
        }
        // Set up the date picker
        let now = scheduler.now
        entryStartDatePicker.timeZone = scheduler.timeZone // mostly useful for UI tests, which use a fake tz
        entryStartDatePicker.maxDate = now
        entryStartDatePicker.dateValue = thisMorning(assumingNow: now)
        
        updateEntries()
        resizeAndLayoutIfNeeded()
    }
    
    override func viewWillAppear() {
        if let window = view.window, let screen = window.screen {
            widthFitsOnScreen.constant = screen.frame.maxX - window.frame.minX
            widthFitsOnScreen.isActive = true
        } else {
            widthFitsOnScreen.isActive = false
        }
    }
    
    func thisMorning(assumingNow now: Date) -> Date {
        Prefs.dayStartTime.map {hh, mm in
            return TimeUtil.dateForTime(.previous, hh: hh, mm: mm, assumingNow: now)
        }
    }
    
    @IBAction func userChangedEntryStartDate(_ sender: Any) {
        animate(
            {
                goalsSummaryStack.subviews.forEach { $0.removeFromSuperview() }
                projectsContainer.subviews.forEach {$0.removeFromSuperview()}
                let spinner = NSProgressIndicator()
                projectsContainer.addArrangedSubview(spinner)
                spinner.startAnimation(self)
                spinner.isIndeterminate = true
                spinner.style = .spinning
                spinner.leadingAnchor.constraint(equalTo: projectsContainer.leadingAnchor).isActive = true
                spinner.trailingAnchor.constraint(equalTo: projectsContainer.trailingAnchor).isActive = true
            },
            andThen: {
                self.animate({ self.updateEntries() })
            }
        )
    }
    
    private func updateGoals(since startTime: Date) {
        goalsSummaryStack.subviews.forEach { $0.removeFromSuperview() }
        
        let oneDayView = startTime >= Prefs.dayStartTime.map {hh, mm in TimeUtil.dateForTime(.previous, hh: hh, mm: mm)}
        let goals = AppDelegate.instance.model.listGoals(since: startTime)
        let completed = goals.filter({$0.isCompleted}).count
        
        let summaryText: String
        if goals.isEmpty {
            summaryText = oneDayView ? "No goals for today." : "No goals for this time range."
        } else {
            summaryText = "Completed \(completed.pluralize("goal", "goals")) out of \(goals.count)."
        }
        goalsSummaryStack.addArrangedSubview(NSTextField(labelWithString: summaryText))
        
        if !goals.isEmpty {
            if oneDayView {
                goals.map(GoalsView.from(_:)).forEach(goalsSummaryStack.addArrangedSubview(_:))
            } else {
                goalsSummaryStack.addArrangedSubview(NSTextField(labelWithAttributedString: NSAttributedString(
                    string: "(not listing them, because you selected more than one day)",
                    attributes: [
                        NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                        NSAttributedString.Key.obliqueness: 0.15
                    ]
                )))
            }
        }
    }
    
    private func updateEntries() {
        let since = entryStartDatePicker.dateValue
        NSLog("Updating entries since %@", since as NSDate)
        updateGoals(since: since)
        projectsContainer.subviews.forEach {$0.removeFromSuperview()}
        
        let projects = Model.GroupedProjects(from: AppDelegate.instance.model.listEntries(since: since))
        let allProjectsTotalTime = projects.totalTime
        let todayStart = thisMorning(assumingNow: scheduler.now)
        projects.forEach {project in
            // The vstack group for the whole project
            let projectVStack = NSStackView()
            projectsContainer.addArrangedSubview(projectVStack)
            projectVStack.spacing = 2
            projectVStack.orientation = .vertical
            projectVStack.widthAnchor.constraint(equalTo: projectsContainer.widthAnchor, constant: -2).isActive = true
            projectVStack.leadingAnchor.constraint(equalTo: projectsContainer.leadingAnchor).isActive = true
            
            let projectHeader = ExpandableProgressBar(
                addTo: projectVStack,
                label: project.name,
                accessibilityLabelScope: "Project",
                withDuration: project.totalTime,
                outOf: allProjectsTotalTime)
            // Tasks box
            let tasksBox = NSBox()
            tasksBox.useAutoLayout()
            projectVStack.addArrangedSubview(tasksBox)
            tasksBox.setAccessibilityLabel("Tasks for \"\(project.name)\"")
            tasksBox.title = tasksBox.accessibilityLabel()!
            tasksBox.titlePosition = .noTitle
            tasksBox.leadingAnchor.constraint(equalTo: projectVStack.leadingAnchor, constant: 3).isActive = true
            tasksBox.trailingAnchor.constraint(equalTo: projectVStack.trailingAnchor, constant: -3).isActive = true
            setUpDisclosureExpansion(disclosure: projectHeader.disclosure, details: tasksBox)
            
            let tasksStack = NSStackView()
            tasksStack.spacing = 0
            tasksStack.orientation = .vertical
            tasksBox.contentView = tasksStack
            
            var previousDetailsBottomAnchor : NSLayoutYAxisAnchor?
            project.forEach {task in
                let taskHeader = ExpandableProgressBar(
                    addTo: tasksStack,
                    label: task.name,
                    accessibilityLabelScope: "Task",
                    withDuration: task.totalTime,
                    outOf: allProjectsTotalTime)
                taskHeader.progressBar.leadingAnchor.constraint(equalTo: projectHeader.progressBar.leadingAnchor).isActive = true
                taskHeader.progressBar.trailingAnchor.constraint(equalTo: projectHeader.progressBar.trailingAnchor).isActive = true
                previousDetailsBottomAnchor?.constraint(equalTo: taskHeader.topView.topAnchor, constant: -5).isActive = true
                
                let taskDetailsGrid = NSGridView(views: [])
                taskDetailsGrid.columnSpacing = 4
                taskDetailsGrid.rowSpacing = 2
                
                let taskDetailsGridBox = NSBox()
                taskDetailsGridBox.useAutoLayout()
                taskDetailsGridBox.setAccessibilityLabel("Details for \(task.name)")
                taskDetailsGridBox.title = taskDetailsGridBox.accessibilityLabel()!
                taskDetailsGridBox.titlePosition = .noTitle
                taskDetailsGridBox.contentView = taskDetailsGrid
                tasksStack.addArrangedSubview(taskDetailsGridBox)
                
                taskDetailsGridBox.leadingAnchor.constraint(equalTo: taskHeader.progressBar.leadingAnchor).isActive = true
                taskDetailsGridBox.trailingAnchor.constraint(equalTo: taskHeader.progressBar.trailingAnchor).isActive = true
                
                previousDetailsBottomAnchor = taskDetailsGridBox.bottomAnchor
                setUpDisclosureExpansion(disclosure: taskHeader.disclosure, details: taskDetailsGridBox) {state in
                    // For some reason, especially long (in terms of vertical space) task notes can break the layout when they're hidden:
                    // It shows up as a large vertial blank space in other tasks. Zeroing out the contents when hidden seems to fix that.
                    if state == .off {
                        while taskDetailsGrid.numberOfRows > 0 {
                            taskDetailsGrid.removeRow(at: 0)
                        }
                        while taskDetailsGrid.numberOfColumns > 0 {
                            taskDetailsGrid.removeColumn(at: 0)
                        }
                    } else {
                        self.details(for: task, to: taskDetailsGrid, relativeTo: todayStart)
                    }
                }
            }
        }
    }
    
    private func details(for task: Model.GroupedTask, to grid: NSGridView, relativeTo todayStart: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.timeZone = scheduler.timeZone
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        
        task.forEach {entry in
            if entry.to < todayStart {
                timeFormatter.dateFormat = "M/d h:mma"
            }
            var taskTime = timeFormatter.string(from: entry.from)
            taskTime += " - "
            if TimeUtil.sameDay(entry.from, entry.to) {
                timeFormatter.dateFormat = "h:mma"
            }
            taskTime += timeFormatter.string(from: entry.to)
            taskTime += " (" + TimeUtil.daysHoursMinutes(for: entry.duration) + "):"
            
            var taskNotes = (entry.notes ?? "").trimmingCharacters(in: .newlines)
            if taskNotes.isEmpty {
                taskNotes = "(no notes entered)"
            }
            let fields = [
                NSTextField(labelWithString: taskTime),
                WhatdidTextField(wrappingLabelWithString: taskNotes),
                NSView()
            ]
            for field in fields {
                if let fieldAsText = field as? NSTextField {
                    fieldAsText.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                }
            }
            grid.addRow(with: fields)
        }
    }
    
    private func animate(_ action: () -> Void, duration: Double = 0.5, andThen: (() -> Void)? = nil) {
        let originalWindowFrameOpt = self.view.window?.frame
        let originalViewBounds = self.view.bounds
        AnimationHelper.animate(
            duration: duration,
            change: {
                action()
                self.resizeAndLayoutIfNeeded()
                
                let newViewBounds = self.view.bounds
                if let window = self.view.window, let originalWindowFrame = originalWindowFrameOpt {
                    let deltaWidth = newViewBounds.width - originalViewBounds.width
                    let deltaHeight = newViewBounds.height - originalViewBounds.height
                    let newWindowFrame = NSRect(
                        x: originalWindowFrame.minX,
                        y: originalWindowFrame.minY - deltaHeight,
                        width: originalWindowFrame.width + deltaWidth,
                        height: originalWindowFrame.height + deltaHeight)
                    window.setFrame(newWindowFrame, display: true)
                }
            },
            onComplete: andThen)
    }
    
    private func resizeAndLayoutIfNeeded() {
        view.layoutSubtreeIfNeeded()
        projectsScrollHeight.constant = projectsContainer.fittingSize.height
        view.layoutSubtreeIfNeeded()
    }
    
    private func setUpDisclosureExpansion(disclosure: ButtonWithClosure, details: NSView, extraAction: ((NSButton.StateValue) -> Void)? = nil) {
        disclosure.onPress {button in
            self.animate({
                details.isHidden = button.state == .off
                if let requestedAction = extraAction {
                    requestedAction(button.state)
                }
            })
        }
        
        details.isHidden = disclosure.state == .off
        if let requestedAction = extraAction {
            requestedAction(disclosure.state)
        }
    }
    
    struct ExpandableProgressBar {
        let topView: NSView
        let disclosure: ButtonWithClosure
        let progressBar: NSProgressIndicator
        
        init(addTo enclosing: NSStackView, label: String, accessibilityLabelScope scope: String, withDuration duration: TimeInterval, outOf: TimeInterval) {
            let labelStack = NSStackView()
            enclosing.addArrangedSubview(labelStack)
            labelStack.orientation = .horizontal
            labelStack.leadingAnchor.constraint(equalTo: enclosing.leadingAnchor).isActive = true
            
            let projectLabel = WhatdidTextField(wrappingLabelWithString: label)
            projectLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            labelStack.addView(projectLabel, in: .leading)
            projectLabel.setAccessibilityLabel("\(scope) \"\(label)\"")
            let durationLabel = WhatdidTextField(wrappingLabelWithString: TimeUtil.daysHoursMinutes(for: duration))
            durationLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            labelStack.addView(durationLabel, in: .trailing)
            durationLabel.setAccessibilityLabel("\(scope) time for \"\(label)\"")
            
            let headerHStack = NSStackView()
            enclosing.addArrangedSubview(headerHStack)
            headerHStack.spacing = 2
            headerHStack.orientation = .horizontal
            headerHStack.widthAnchor.constraint(equalTo: enclosing.widthAnchor).isActive = true
            headerHStack.leadingAnchor.constraint(equalTo: enclosing.leadingAnchor).isActive = true
            // disclosure button
            disclosure = createDisclosure(state: .off)
            headerHStack.addArrangedSubview(disclosure)
            disclosure.leadingAnchor.constraint(equalTo: headerHStack.leadingAnchor).isActive = true
            disclosure.setAccessibilityLabel("\(scope) details toggle for \"\(label)\"")
            
            // progress bar
            progressBar = NSProgressIndicator()
            headerHStack.addArrangedSubview(progressBar)
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = outOf
            progressBar.doubleValue = duration
            progressBar.trailingAnchor.constraint(lessThanOrEqualTo: headerHStack.trailingAnchor).isActive = true
            progressBar.trailingAnchor.constraint(equalTo: labelStack.trailingAnchor).isActive = true
            progressBar.setAccessibilityLabel("\(scope) activity indicator for \"\(label)\"")
            
            topView = labelStack
        }
    }
}
