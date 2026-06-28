import XCTest

import PromiseTests

var tests = [XCTestCaseEntry]()
tests += PromiseTests.allTests()
XCTMain(tests)
