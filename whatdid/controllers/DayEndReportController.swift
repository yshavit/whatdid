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
    @IBOutlet weak var projectsContainer: NSStackView!
    @IBOutlet weak var projectsWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var entryStartDatePicker: NSDatePicker!
    @IBOutlet weak var shockAbsorber: NSView!
    private var scrollBarHelper: ScrollBarHelper?

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
            wdlog(.debug, "set max height to %.1f (screen height is %.1f)", maxViewHeight.constant, screenHeight)
        }
        // Set up the date picker
        let now = scheduler.now
        entryStartDatePicker.timeZone = scheduler.timeZone // mostly useful for UI tests, which use a fake tz
        entryStartDatePicker.maxDate = now
        entryStartDatePicker.dateValue = thisMorning(assumingNow: now)
        
        updateEntries()
    }
    
    override func viewWillAppear() {
        if let scroller = projectsScroll.verticalScroller {
            scrollBarHelper = ScrollBarHelper(on: scroller) {
                self.projectsWidthConstraint.constant = $0
            }
        }
        
        if let window = view.window, let screen = window.screen {
            widthFitsOnScreen.constant = screen.frame.maxX - window.frame.minX
            widthFitsOnScreen.isActive = true
        } else {
            widthFitsOnScreen.isActive = false
        }
    }
    
    override func viewWillDisappear() {
        scrollBarHelper = nil
    }
    
    func thisMorning(assumingNow now: Date) -> Date {
        Prefs.dayStartTime.map {hh, mm in
            return TimeUtil.dateForTime(.previous, hh: hh, mm: mm, assumingNow: now)
        }
    }
    
    @IBAction func userChangedEntryStartDate(_ sender: Any) {
        AnimationHelper.animate(
            change: {
                goalsSummaryStack.subviews.forEach { $0.removeFromSuperview() }
                projectsContainer.subviews.forEach {$0.removeFromSuperview()}
                let spinner = NSProgressIndicator()
                projectsContainer.addArrangedSubview(spinner)
                spinner.startAnimation(self)
                spinner.isIndeterminate = true
                spinner.style = .spinning
                spinner.leadingAnchor.constraint(equalTo: projectsContainer.leadingAnchor).isActive = true
                spinner.trailingAnchor.constraint(equalTo: projectsContainer.trailingAnchor).isActive = true
                self.resizeAndLayoutIfNeeded()
            },
            onComplete: {
                AnimationHelper.animate(change: self.updateEntries)
            })
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
        wdlog(.debug, "Updating entries since %@", since as NSDate)
        updateGoals(since: since)
        projectsContainer.subviews.forEach {$0.removeFromSuperview()}
        
        let projects = Model.GroupedProjects(from: AppDelegate.instance.model.listEntries(since: since))
        let allProjectsTotalTime = projects.totalTime
        let todayStart = thisMorning(assumingNow: scheduler.now)
        projects.forEach {project in
            // The vstack group for the whole project
            let projectVStack = NSStackView()
            projectVStack.wantsLayer = true
            projectVStack.useAutoLayout()
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
            tasksBox.setAccessibilityLabel("Tasks for \"\(project.name)\"")
            tasksBox.title = tasksBox.accessibilityLabel()!
            tasksBox.titlePosition = .noTitle
            let tasksStack = NSStackView()
            tasksStack.wantsLayer = true
            tasksStack.useAutoLayout()
            tasksStack.spacing = 0
            tasksStack.orientation = .vertical
            tasksBox.contentView = tasksStack
            tasksBox.anchorAllSides(to: tasksStack)
            
            let taskExpansion = setUpDisclosureExpansion(disclosure: projectHeader.disclosure, add: tasksBox, to: projectVStack)
            projectVStack.addArrangedSubview(taskExpansion)
            tasksBox.leadingAnchor.constraint(equalTo: projectVStack.leadingAnchor, constant: 3).isActive = true
            tasksBox.trailingAnchor.constraint(equalTo: projectVStack.trailingAnchor, constant: -3).isActive = true
            
            project.forEach {task in
                let taskHeader = ExpandableProgressBar(
                    addTo: tasksStack,
                    label: task.name,
                    accessibilityLabelScope: "Task",
                    withDuration: task.totalTime,
                    outOf: allProjectsTotalTime)
                taskHeader.progressBar.leadingAnchor.constraint(equalTo: projectHeader.progressBar.leadingAnchor).isActive = true
                taskHeader.progressBar.trailingAnchor.constraint(equalTo: projectHeader.progressBar.trailingAnchor).isActive = true
                
                let taskDetailsGrid = NSGridView(views: [])
                taskDetailsGrid.columnSpacing = 4
                taskDetailsGrid.rowSpacing = 2
                
                let taskDetailsGridBox = NSBox()
                taskDetailsGridBox.useAutoLayout()
                taskDetailsGridBox.setAccessibilityLabel("Details for \(task.name)")
                taskDetailsGridBox.title = taskDetailsGridBox.accessibilityLabel()!
                taskDetailsGridBox.titlePosition = .noTitle
                taskDetailsGridBox.contentView = taskDetailsGrid
                
                let taskExpansion = setUpDisclosureExpansion(
                    disclosure: taskHeader.disclosure,
                    add: taskDetailsGridBox,
                    to: tasksStack,
                    beforeShowing: {
                        self.details(for: task, to: taskDetailsGrid, relativeTo: todayStart)
                    },
                    afterHiding: {
                        while taskDetailsGrid.numberOfRows > 0 {
                            taskDetailsGrid.removeRow(at: 0)
                        }
                        while taskDetailsGrid.numberOfColumns > 0 {
                            taskDetailsGrid.removeColumn(at: 0)
                        }
                        taskDetailsGrid.subviews.forEach({$0.removeFromSuperview()})
                    })
                tasksStack.addArrangedSubview(taskExpansion)
                taskExpansion.leadingAnchor.constraint(equalTo: taskHeader.progressBar.leadingAnchor).isActive = true
                taskExpansion.trailingAnchor.constraint(equalTo: taskHeader.progressBar.trailingAnchor).isActive = true
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

    private func resizeAndLayoutIfNeeded() {
        view.layoutSubtreeIfNeeded()
        let shockAbsorberHeight = shockAbsorber.frame.height
        growWindow(byY: -shockAbsorberHeight)
    }
    
    private func growWindow(byY height: CGFloat) {
        guard let window = view.window else {
            wdlog(.warn, "Asked to grow window, but there is no window")
            return
        }
        let originalViewBounds = window.frame
        let newFrame = NSRect(
            x: originalViewBounds.minX,
            y: originalViewBounds.minY - height,
            width: originalViewBounds.width,
            height: originalViewBounds.height + height
        )
        window.setFrame(newFrame, display: true)
        view.layoutSubtreeIfNeeded()
    }
    
    private func setUpDisclosureExpansion(
        disclosure: ButtonWithClosure,
        add details: NSView,
        to enclosing: NSView,
        beforeShowing: @escaping Action = {},
        afterHiding: @escaping Action = {})
    -> NSView
    {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.masksToBounds = true
        wrapper.addSubview(details)
        wrapper.widthAnchor.constraint(equalTo: details.widthAnchor).isActive = true
        let zeroHeight = wrapper.heightAnchor.constraint(equalToConstant: 0)
        let contentHeight = wrapper.heightAnchor.constraint(equalTo: details.heightAnchor)
        
        func setConstraints(toShow: Bool) {
            // We don't want to do e.g. `contentHeight.isActive = toShow` because we always want to deactivate
            // the old constraint before activating the new one. Otherwise they can conflict, which causes one to
            // get thrown out.
            if toShow {
                zeroHeight.isActive = false
                contentHeight.isActive = true
            } else {
                contentHeight.isActive = false
                zeroHeight.isActive = true
            }
        }
        
        if disclosure.state == .on {
            beforeShowing()
            setConstraints(toShow: true)
        } else {
            afterHiding()
            setConstraints(toShow: false)
        }
        
        disclosure.onPress {button in
            if button.state == .on {
                beforeShowing()
                AnimationHelper.animate(
                    change: {
                        setConstraints(toShow: true)
                        let currentHeight = self.view.frame.height
                        let maxHeight = self.maxViewHeight.constant
                        var growBy = details.fittingSize.height
                        if (growBy + currentHeight) > maxHeight {
                            growBy = maxHeight - currentHeight
                        }
                        self.growWindow(byY: growBy)
                    },
                    onComplete: {
                        AnimationHelper.animate(duration: 0.2, change: self.resizeAndLayoutIfNeeded)
                    })
            } else {
                AnimationHelper.animate(
                    change: {
                        setConstraints(toShow: false)
                        self.growWindow(byY: -details.fittingSize.height)
                    },
                    onComplete: {
                        afterHiding()
                        AnimationHelper.animate(duration: 0.2, change: self.resizeAndLayoutIfNeeded)
                    })
            }
        }
        return wrapper
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
