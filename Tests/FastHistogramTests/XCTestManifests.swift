import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HistogramGeneratorTests.allTests),
        testCase(HistogramRendererTests.allTests),
        testCase(SharedResourcePoolTests.allTests),
    ]
}
#endif
