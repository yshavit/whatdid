import Cocoa

struct Atomic {
    
    private init() {
        // nothing
    }
    
    private static let varDispatch = DispatchQueue(label: "com.yuvalshavit.wtfdid.atomic", qos: .default)
    
    @propertyWrapper class Var<T> {
        
        private var value : T

        init(wrappedValue: T) {
            self.value = wrappedValue
        }
    
        var wrappedValue: T {
            get {
                return varDispatch.sync(execute: {
                    return self.value
                })
            }
            set(value) {
                varDispatch.async {
                    self.value = value
                }
            }
        }
        
    }
    
}
