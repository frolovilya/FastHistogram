import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HistogramGeneratorTests.allTests),
        testCase(SharedResourcePoolTests.allTests),
    ]
}
#endif
