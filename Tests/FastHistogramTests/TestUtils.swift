import Foundation

class TestUtils {
 
    private init() {}
    
    static let gamma: Double = 2.4
    
    static let redPerception: Double = 0.2126
    static let greenPerception: Double = 0.7152
    static let bluePerception: Double = 0.0722
    
    static func linearize(_ value: Double) -> Double {
        pow((value + 0.055) / 1.055, 2.4)
    }
    
    static func binIndex(_ value: Double, binsCount: Int) -> Int {
        Int(round(value * Double(binsCount - 1)))
    }

}
