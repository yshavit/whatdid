// whatdid?

import Cocoa

class DayEndReportController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBOutlet weak var maxViewHeight: NSLayoutConstraint!
    @IBOutlet weak var projectsScroll: NSScrollView!
    @IBOutlet weak var projectsScrollHeight: NSLayoutConstraint!
    @IBOutlet weak var projectsContainer: NSStackView!
    @IBOutlet weak var entryStartDatePicker: NSDatePicker!
    
    @IBOutlet weak var versionLabel: NSTextField!
    
    override func awakeFromNib() {
        if #available(OSX 10.15.4, *) {
            entryStartDatePicker.presentsCalendarOverlay = true
        }
        versionLabel.stringValue = Version.pretty
    }
    
    private static func createDisclosure(state: NSButton.StateValue)  -> ButtonWithClosure {
        let result = ButtonWithClosure()
        result.state = state
        result.setButtonType(.pushOnPushOff)
        result.bezelStyle = .disclosure
        result.imagePosition = .imageOnly
        return result
    }
    
    override func viewWillAppear() {
        // Set the window's max height, using the golden ratio.
        if let screenHeight = view.window?.screen?.frame.height {
            maxViewHeight.constant = screenHeight * 0.61802903
            NSLog("set max height to %.1f (screen height is %.1f)", maxViewHeight.constant, screenHeight)
        }
        // Set up the date picker
        let now = DefaultScheduler.instance.now
        entryStartDatePicker.maxDate = now
        entryStartDatePicker.dateValue = thisMorning(assumingNow: now)
        
        updateEntries()
    }
    
    func thisMorning(assumingNow now: Date) -> Date {
        return TimeUtil.dateForTime(.previous, hh: 07, mm: 00, assumingNow: now)
    }
    
    @IBAction func userChangedEntryStartDate(_ sender: Any) {
        animate(
            {
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
    
    private func updateEntries() {
        let since = entryStartDatePicker.dateValue
        NSLog("Updating entries since %@", since as NSDate)
        projectsContainer.subviews.forEach {$0.removeFromSuperview()}
        
        let projects = Model.GroupedProjects(from: AppDelegate.instance.model.listEntries(since: since))
        let allProjectsTotalTime = projects.totalTime
        let todayStart = thisMorning(assumingNow: DefaultScheduler.instance.now)
        projects.forEach {project in
            // The vstack group for the whole project
            let projectVStack = NSStackView()
            projectsContainer.addArrangedSubview(projectVStack)
            projectVStack.spacing = 2
            projectVStack.orientation = .vertical
            projectVStack.widthAnchor.constraint(equalTo: projectsContainer.widthAnchor, constant: -2).isActive = true
            projectVStack.leadingAnchor.constraint(equalTo: projectsContainer.leadingAnchor).isActive = true
            
            let projectHeader = ExpandableProgressBar(addTo: projectVStack, labeled: project.name, withDuration: project.totalTime, outOf: allProjectsTotalTime)
            
            // Tasks box
            let tasksBox = NSBox()
            projectVStack.addArrangedSubview(tasksBox)
            tasksBox.title = "Tasks for \(project.name)"
            tasksBox.titlePosition = .noTitle
            tasksBox.leadingAnchor.constraint(equalTo: projectVStack.leadingAnchor, constant: 3).isActive = true
            tasksBox.trailingAnchor.constraint(equalTo: projectVStack.trailingAnchor, constant: -3).isActive = true
            setUpDisclosureExpansion(disclosure: projectHeader.disclosure, details: tasksBox)
            
            let tasksStack = NSStackView()
            tasksStack.spacing = 0
            tasksStack.orientation = .vertical
            tasksBox.contentView = tasksStack
            
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.dateFormat = "h:mma"
            timeFormatter.timeZone = DefaultScheduler.instance.timeZone
            timeFormatter.amSymbol = "am"
            timeFormatter.pmSymbol = "pm"
            
            
            var previousDetailsBottomAnchor : NSLayoutYAxisAnchor?
            project.forEach {task in
                let taskHeader = ExpandableProgressBar(addTo: tasksStack, labeled: task.name, withDuration: task.totalTime, outOf: allProjectsTotalTime)
                taskHeader.progressBar.leadingAnchor.constraint(equalTo: projectHeader.progressBar.leadingAnchor).isActive = true
                taskHeader.progressBar.trailingAnchor.constraint(equalTo: projectHeader.progressBar.trailingAnchor).isActive = true
                previousDetailsBottomAnchor?.constraint(equalTo: taskHeader.topView.topAnchor, constant: -5).isActive = true
                var details = ""
                task.forEach {entry in
                    if entry.to < todayStart {
                        timeFormatter.dateFormat = "M/d h:mma"
                    }
                    details += timeFormatter.string(from: entry.from)
                    details += " - "
                    if TimeUtil.sameDay(entry.from, entry.to) {
                        timeFormatter.dateFormat = "h:mma"
                    }
                    details += timeFormatter.string(from: entry.to)
                    details += " (" + TimeUtil.daysHoursMinutes(for: entry.duration) + "): "
                    details += entry.notes ?? "(no notes entered)"
                    details += "\n"
                }
                let taskDescriptions = details.trimmingCharacters(in: .newlines)
                let taskDetailsView = NSTextField(labelWithString: taskDescriptions)
                tasksStack.addArrangedSubview(taskDetailsView)
                taskDetailsView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                taskDetailsView.leadingAnchor.constraint(equalTo: taskHeader.progressBar.leadingAnchor).isActive = true
                previousDetailsBottomAnchor = taskDetailsView.bottomAnchor
                // For some reason, especially long (in terms of vertical space) tasks can break the layout when they're hidden:
                // It shows up as a large vertial blank space. Something something intrinsic size? Anyway, zeroing out the contents
                // when hidden seems to fix that.
                let removeTextWhenHidden : (NSButton.StateValue) -> Void = {state in
                    taskDetailsView.stringValue = state == .off ? "" : taskDescriptions
                }
                setUpDisclosureExpansion(disclosure: taskHeader.disclosure, details: taskDetailsView, extraAction: removeTextWhenHidden)
            }
        }
    }
    
    private func animate(_ action: () -> Void, duration: Double = 0.5, andThen: (() -> Void)? = nil) {
        let originalWindowFrameOpt = self.view.window?.frame
        let originalViewBounds = self.view.bounds
        NSAnimationContext.runAnimationGroup(
            {context in
                context.duration = duration
                context.allowsImplicitAnimation = true
                action()
                self.projectsScrollHeight.constant = self.projectsContainer.fittingSize.height
                self.view.layoutSubtreeIfNeeded()
                
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
            completionHandler: andThen
        )
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
        self.projectsScrollHeight.constant = self.projectsContainer.fittingSize.height
        self.view.layoutSubtreeIfNeeded()
    }
    
    struct ExpandableProgressBar {
        let topView: NSView
        let disclosure: ButtonWithClosure
        let progressBar: NSProgressIndicator
        
        init(addTo enclosing: NSStackView, labeled label: String, withDuration duration: TimeInterval, outOf: TimeInterval) {
            let labelStack = NSStackView()
            enclosing.addArrangedSubview(labelStack)
            labelStack.orientation = .horizontal
            labelStack.leadingAnchor.constraint(equalTo: enclosing.leadingAnchor).isActive = true
            
            let projectLabel = NSTextField(labelWithString: label)
            projectLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            labelStack.addView(projectLabel, in: .leading)
            let durationLabel = NSTextField(labelWithString: TimeUtil.daysHoursMinutes(for: duration))
            durationLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            labelStack.addView(durationLabel, in: .trailing)
            
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
            
            // progress bar
            progressBar = NSProgressIndicator()
            headerHStack.addArrangedSubview(progressBar)
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = outOf
            progressBar.doubleValue = duration
            progressBar.trailingAnchor.constraint(lessThanOrEqualTo: headerHStack.trailingAnchor).isActive = true
            progressBar.trailingAnchor.constraint(equalTo: labelStack.trailingAnchor).isActive = true
            
            topView = labelStack
        }
    }
    
    private func getEntries() -> [FlatEntry] {
        func d(_ hh: Int, _ mm: Int) -> Date {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-4:00"
            return dateFormatter.date(from: String(format: "2020-07-31T%02d:%02d:00-4:00", hh, mm))!
        }
        var fakeEntries = [
            FlatEntry(from: d(10, 00), to: d(10, 15), project: "Project1", task: "Task 1", notes: "entry 1"),
            FlatEntry(from: d(10, 15), to: d(10, 30), project: "Project1", task: "Task 1", notes: "entry 2"),
            FlatEntry(from: d(10, 30), to: d(10, 45), project: "Project1", task: "Task 2", notes: "entry 3"),
            FlatEntry(from: d(10, 45), to: d(11, 00), project: "Project2", task: "Task 1", notes: "entry 4"),
            FlatEntry(from: d(10, 45), to: d(10, 55), project: String(repeating: "long project ", count: 30), task: String(repeating: "long task", count: 20), notes: String(repeating: "long entry", count: 20)),
        ]
        (0..<10).forEach {hh in
            (0..<4).forEach {qh in // quarter hour
                fakeEntries.append(FlatEntry(
                    from: d(12 + hh, qh * 15),
                    to: d(12 + hh, qh * 15 + 14),
                    project: "Marathon project",
                    task: "big task #\(qh)",
                    notes: "session \(hh)"))
            }
            
        }
        return fakeEntries.shuffled() // to make it interesting :)
    }
}
