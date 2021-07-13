import XCTest

import FastHistogramTests

var tests = [XCTestCaseEntry]()
tests += HistogramGeneratorTests.allTests()
tests += SharedResourcePoolTests.allTests()
XCTMain(tests)
