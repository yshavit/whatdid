// whatdid?

import Cocoa

class DayEndReportController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBOutlet weak var projectsScroll: NSScrollView!
    @IBOutlet weak var projectsContainer: NSStackView!
    
    override func viewWillAppear() {
//        projectsContainer.subviews.forEach {$0.removeFromSuperview()}
        _ = Model.group(entries: getEntries()) // TODO read from Model
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
