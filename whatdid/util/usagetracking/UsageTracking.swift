// whatdid?

import Foundation

class UsageTracking {
    static let PRIVACY_URL = "https://whatdid.yuvalshavit.com/privacy"
    static let SEND_INTERVALS = 30.0 // TODO every 5 minutes
    static let SEND_URL = URL(string: "https://api.whatdid.yuvalshavit.com/analytics/usage")!
    
    private var model: Model?
    private let lock = NSRecursiveLock()
    private var enabled = false
    private var backgroundRetrySendTask: DispatchWorkItem?
    
    static let instance = UsageTracking()
    
    /// A private initializer, so that all analytics come in through `UsageTracking.instance`. This makes it easier to find call sites.
    private init() {}
    
    func setModel(_ model: Model) {
        lock.synchronized {
            self.model = model
        }
    }
    
    func setEnabled(_ shouldBeEnabled: Bool) {
        lock.synchronized {
            if shouldBeEnabled == enabled {
                return // already done!
            }
            enabled = shouldBeEnabled
            if shouldBeEnabled {
                self.scheduleDeferredSend()
            } else if let backgroundRetrySendTask = backgroundRetrySendTask {
                backgroundRetrySendTask.cancel()
            }
        }
    }
    
    /// Convenience method for `UsageTracking.instance.recordAction(action)`.
    static func recordAction(_ action: UsageAction) {
        UsageTracking.instance.recordAction(action)
    }
    
    func recordAction(_ action: UsageAction) {
        let (enabled, model) = lock.synchronizedGet { (self.enabled, self.model) }
        if !enabled {
            return
        }
        guard let model = model else {
            wdlog(.warn, "analytics ignoring usage datum because there's no model set")
            return
        }
        model.createUsage(action: action, andThen: {datum in self.immediatelySend(data: [datum])})
    }
    
    private func scheduleDeferredSend() {
        let newTask = lock.synchronizedGet {() -> DispatchWorkItem? in
            // Never schedule a send if analytics has been disabled!
            if !enabled {
                return nil
            }
            // If there's already a background task scheduled, we don't need to do anything.
            if backgroundRetrySendTask == nil {
                let task = DispatchWorkItem(qos: .background, block: self.immediatelyRetryAllUnsents)
                backgroundRetrySendTask = task
                return task
            }
            return nil
        }
        if let newTask = newTask {
            DispatchQueue.global(qos: .background).asyncAfter(
                deadline: DispatchTime.now() + UsageTracking.SEND_INTERVALS,
                execute: newTask)
        }
    }
    
    private func immediatelySend(data: [UsageDatumDTO]) {
        if data.isEmpty {
            return
        }
        
        var req = URLRequest(url: UsageTracking.SEND_URL)
        req.httpMethod = "POST"
        
        let dataDTOs = data.map(UsageTrackingJsonDatum.init(from:))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        do {
            req.httpBody = try encoder.encode(dataDTOs)
        } catch {
            wdlog(.error, "couldn't serialize analytics data")
            return
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        

        let task = URLSession.shared.dataTask(with: req) {urlData, res, err in
            let dataStr: String
            if let urlData = urlData {
                dataStr = String(data: urlData, encoding: .utf8) ?? "<response decoding error>"
            } else {
                dataStr = "<response had no data>"
            }
            if let err = err {
                wdlog(.error, "couldn't send analytics data: %s (%s)", err.localizedDescription, dataStr)
                self.scheduleDeferredSend()
            } else if let res = res as? HTTPURLResponse, (res.statusCode < 200 || res.statusCode >= 300) {
                wdlog(.error, "got HTTP error when sending analytics data: %d %s", res.statusCode, dataStr)
                self.scheduleDeferredSend()
            } else {
                wdlog(.info, "successfully submitted analytic data")
                for datum in data {
                    self.model?.recordAnalyticSubmitted(datum)
                }
            }
        }
        task.resume()
    }
    
    private func immediatelyRetryAllUnsents() {
        /// Threading concerns:
        /// We first atomically: { get the current background task, and clear it out }.
        /// (That task is _probably_ the one that's currently executing this func, but just in case it isn't, we also cancel it.)
        /// That means that if someone requests a new task right before that synchronized block, we'll include its action in this current run. Othewise, the request
        /// will block until this synchronizedGet ends, at which point `backgroundRetrySendTask` will be `nil` and ready to accept a new scheduled run.
        let (enabled, currentTask) = lock.synchronizedGet {() -> (Bool, DispatchWorkItem?) in
            let currentTask = self.backgroundRetrySendTask
            self.backgroundRetrySendTask = nil
            return (self.enabled, currentTask)
        }
        if let currentTask = currentTask {
            // The current task is probably the one that this is running in, but just in case it's not, cancel it.
            currentTask.cancel()
        }
        if !enabled {
            return
        }
        model?.getUnsentUsages {unsents in
            if unsents.isEmpty || !self.lock.synchronizedGet({self.enabled}) {
                return
            }
            
            self.immediatelySend(data: unsents)
            self.scheduleDeferredSend() // There may be another batch!
        }
    }
}
