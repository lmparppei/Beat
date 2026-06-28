//
//  File.swift
//  
//
//  Created by yuki on 2023/05/27.
//

import XCTest
import Promise

final class PromiseConcurrencyTests: XCTestCase {
    
    func testNestedPromiseWithAsyncContext() async throws {        
        let value = await Promise {
            await Promise {
                await Promise<Int, Never>.resolve(10).value
            }.value
        }.value

        XCTAssertEqual(value, 10)
    }

    func testNestedPromiseWithAsyncContextWithError() async throws {
        var throwed = false
        do {
            try await Promise {
                try await Promise {
                    throw PromiseTestError()
                }.value
            }.value
        } catch {
            throwed = true
        }
        XCTAssert(throwed)
    }
}
