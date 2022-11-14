// whatdidTests?

import XCTest
@testable import whatdid

class ControllerTestBase<T: NSViewController>: XCTestCase {

    private(set) var thisMorning: Date!
    private var model: Model!

    override func setUpWithError() throws {
        thisMorning = TimeUtil.dateForTime(.previous, hh: 9, mm: 00)
    }

    func loadModel(withData dataLoader: (DataBuilder) -> Void) -> Model {
        let uniqueName = name.replacingOccurrences(of: "\\W", with: "", options: .regularExpression)
        model = Model(modelName: uniqueName, clearAllEntriesOnStartup: true)
        // fetch the (empty set of) entries, to force the model's lazy loading. Otherwise, the unit test's adding of entries can
        // race with the controller's fetching of them, such that they both try to clear out the same set of old files (and
        // whoever gets there second, fails due to those files not being there.)
        let _ = model.listEntries(from: thisMorning, to: DefaultScheduler.instance.now)

        let dataBuilder = DataBuilder(using: model, startingAt: thisMorning)
        dataLoader(dataBuilder)

        // Wait until we have as many entries as our DataBuilder expects
        let timeoutAt = Date().addingTimeInterval(3)
        while model.listEntries(from: Date.distantPast, to: Date.distantFuture).count < dataBuilder.expected {
            usleep(50000)
            XCTAssertLessThan(Date(), timeoutAt)
        }
        return model
    }

    func createController(withData dataLoader: (DataBuilder) -> Void) -> T {
        let _ = loadModel(withData: dataLoader)
        if let nib = NSNib(nibNamed: nibName, bundle: Bundle(for: T.self)) {
            var topLevelObjects: NSArray? = NSArray()
            nib.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects)
            if let controller = topLevelObjects?.compactMap({$0 as? T}).first {
                controller.viewDidLoad()
                load(model: model, into: controller)
                return controller
            } else {
                XCTFail("couldn't find EntriesTreeController in nib")
            }
        } else {
            XCTFail("couldn't load nib")
        }
        fatalError()
    }

    func load(model: Model, into controller: T) {
        XCTFail("must override this method!")
    }

    var nibName: String {
        T.className().replacingOccurrences(of: "^.*\\.", with: "", options: .regularExpression)
    }

    class DataBuilder {
        private let model: Model
        private let startingAt: Date
        private var lastEventOffset = TimeInterval(0)
        private(set) var expected = 0
        /// An offset that's applied to all events (after you set this; it's not retroactive).
        var eventOffset = TimeInterval(0)

        init(using model: Model, startingAt: Date) {
            self.model = model
            self.startingAt = startingAt
        }

        func add(project: String, task: String, note: String, withDuration minutes: Int) {
            let thisTaskDuration = TimeInterval(minutes * 60)
            let from = startingAt.addingTimeInterval(lastEventOffset + eventOffset)
            let to = from.addingTimeInterval(thisTaskDuration)
            let entry = FlatEntry(from: from, to: to, project: project, task: task, notes: note)
            model.add(entry, andThen: {})
            lastEventOffset += thisTaskDuration
            expected += 1
        }
    }
}
