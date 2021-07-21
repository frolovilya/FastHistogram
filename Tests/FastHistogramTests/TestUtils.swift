import Foundation

class TestUtils {
 
    private init() {}
    
    static func linearize(_ value: Double) -> Double {
        pow((value + 0.055) / 1.055, 2.4)
    }
    
    static func binIndex(_ value: Double, binsCount: Int) -> Int {
        Int(round(value * Double(binsCount - 1)))
    }

}
