// whatdid?

import Cocoa

class DayEndReportController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    /// I don't know how to programatically make a nice disclosure button, so I'll just let the xib do it for me :-)
    @IBOutlet var disclosurePrototype: ButtonWithClosure!
    // The serialized version of `disclosurePrototype`
    private static var disclosureArchive : Data!
    @IBOutlet weak var projectsScroll: NSScrollView!
    
    @IBOutlet weak var projectsScrollHeight: NSLayoutConstraint!
    @IBOutlet weak var projectsContainer: NSStackView!
    
    override func awakeFromNib() {
        do {
            DayEndReportController.disclosureArchive = try NSKeyedArchiver.archivedData(withRootObject: disclosurePrototype!, requiringSecureCoding: false)
            disclosurePrototype = nil // free it up
        } catch {
            NSLog("Couldn't archive disclosure button: %@", error as NSError)
        }
    }
    
    private static func createDisclosure(state: NSButton.StateValue)  -> ButtonWithClosure {
        do {
            // TODO eventually I should look at the xib xml and just figure out what it's doing
            let new = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(disclosureArchive)
            let button = new as! ButtonWithClosure
            button.state = state
            return button
        } catch {
            NSLog("error: %@", error as NSError) // TODO return default?
            fatalError("error: \(error)")
        }
    }
    
    private func DEBUG(_ stack: NSStackView, _ color: NSColor) {
        stack.wantsLayer = true
        stack.layer?.backgroundColor = color.cgColor
    }
    
    override func viewWillAppear() {
        projectsContainer.subviews.forEach {$0.removeFromSuperview()}
        
        let projects = Model.GroupedProjects(from: getEntries()) // TODO read from Model
        let allProjectsTotalTime = projects.totalTime
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
            timeFormatter.dateFormat = "HH:mma"
            timeFormatter.timeZone = .autoupdatingCurrent
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
                    details += timeFormatter.string(from: entry.from)
                    details += " - "
                    details += timeFormatter.string(from: entry.to)
                    details += ": "
                    details += entry.notes ?? "(no notes entered)"
                    details += "\n"
                }
                let taskDetailsView = NSTextField(labelWithString: details.trimmingCharacters(in: .newlines))
                tasksStack.addArrangedSubview(taskDetailsView)
                taskDetailsView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                taskDetailsView.leadingAnchor.constraint(equalTo: taskHeader.progressBar.leadingAnchor).isActive = true
                previousDetailsBottomAnchor = taskDetailsView.bottomAnchor
                setUpDisclosureExpansion(disclosure: taskHeader.disclosure, details: taskDetailsView)
            }
        }
    }
    
    private func setUpDisclosureExpansion(disclosure: ButtonWithClosure, details: NSView) {
        disclosure.onPress {button in
            NSAnimationContext.runAnimationGroup {context in
                context.duration = 0
                context.allowsImplicitAnimation = true
                
                details.isHidden = button.state == .off
                self.projectsScrollHeight.constant = self.projectsContainer.fittingSize.height
                self.view.layoutSubtreeIfNeeded()
            }
        }
        
        details.isHidden = disclosure.state == .off
        self.projectsScrollHeight.constant = self.projectsContainer.fittingSize.height
        self.view.layoutSubtreeIfNeeded()
    }
    
    struct ExpandableProgressBar {
        let topView: NSView
        let disclosure: ButtonWithClosure
        let progressBar: NSProgressIndicator
        
        init(addTo enclosing: NSStackView, labeled label: String, withDuration duration: TimeInterval, outOf: TimeInterval) {
            let projectLabel = NSTextField(labelWithString: label)
            enclosing.addArrangedSubview(projectLabel)
            projectLabel.leadingAnchor.constraint(equalTo: enclosing.leadingAnchor).isActive = true
            
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
            
            topView = projectLabel
        }
    }
    
    private func getEntries() -> [Model.FlatEntry] {
        func d(_ hh: Int, _ mm: Int) -> Date {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-4:00"
            return dateFormatter.date(from: String(format: "2020-07-31T%02d:%02d:00-4:00", hh, mm))!
        }
        return [
            .init(from: d(10, 00), to: d(10, 15), project: "Project1", task: "Task 1", notes: "entry 1"),
            .init(from: d(10, 15), to: d(10, 30), project: "Project1", task: "Task 1", notes: "entry 2"),
            .init(from: d(10, 30), to: d(10, 45), project: "Project1", task: "Task 2", notes: "entry 3"),
            .init(from: d(10, 45), to: d(11, 00), project: "Project2", task: "Task 1", notes: "entry 4"),
        ].shuffled() // to make it interesting :)
    }
}
