// whatdid?

import Foundation

class SimpleRandom {
    private var curr: UInt32
    
    init(seed: UInt32) {
        curr = seed
        _ = nextUInt32()
    }
    
    func nextUInt32() -> UInt32 {
        curr ^= curr << 6;
        curr ^= curr >> 21; // Java has >>> for signed ints
        curr ^= (curr << 7);
        return curr;
    }
    
    /// Returns a number from 0 to 1.0
    func nextUnitFloat() -> Float {
        return nextUInt32().asUnitFloat
    }
    
    func nextFloat(from: Float, to: Float) -> Float {
        guard from.isFinite && to.isFinite && from < to else {
            return Float.nan
        }
        let unitFloat = nextUnitFloat()
        return unitFloat * (from - to) + from
    }
}
