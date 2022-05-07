// whatdid?

import Foundation

extension UInt32 {
    public var asUnitFloat: Float {
        let uintAsDouble = Double(self)
        let scaledTo1 = uintAsDouble / Double(UInt32.max)
        return Float(scaledTo1)
    }
}
