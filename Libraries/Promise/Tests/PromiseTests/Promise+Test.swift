//
//  Promise+Test.swift
//  
//
//  Created by yuki on 2023/08/09.
//

import XCTest
import Promise

extension Promise {
    public func waitUntilExit(_ testCase: XCTestCase, timeout: TimeInterval = 1) {
        let expectation = testCase.expectation(description: "Promise should exit")
        self
            .catch { XCTFail("Promise exited with error: \($0)") }
            .finally { expectation.fulfill() }
        testCase.wait(for: [expectation], timeout: timeout)
    }
}
