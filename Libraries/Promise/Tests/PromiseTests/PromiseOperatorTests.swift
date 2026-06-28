//
//  File.swift
//  
//
//  Created by yuki on 2023/08/15.
//

import XCTest
import Promise

struct PromiseTestError: Error {}

final class PromiseOperatorTests: XCTestCase {
    
    func testPromise_CallbackInit() throws {
        Promise<String, Never>{ resolve, _ in
            DispatchQueue.main.async { resolve("Hello World") }
        }
        .peek { XCTAssertEqual($0, "Hello World") }
        .waitUntilExit(self)
    }
    
    func testPromise_Map() throws {
        Promise<String, Never>.resolve("Hello World")
            .map { $0 + "!" }
            .peek { XCTAssertEqual($0, "Hello World!") }
            .waitUntilExit(self)
    }
    
    func testPromise_FlatMap() throws {
        Promise<String, Never>.resolve("Hello World")
            .flatMap { .resolve($0 + "!!!") }
            .peek { XCTAssertEqual($0, "Hello World!!!") }
            .waitUntilExit(self)
    }
    
    func testPromise_Reject() throws {
        var call = 0
        
        Promise<Void, PromiseTestError>.reject(PromiseTestError())
            .peek { XCTFail("Should not be called") }
            .catch { _ in call += 1 }
            .waitUntilExit(self)
        
        XCTAssertEqual(call, 1)
    }
    
    func testPromise_Chain() throws {
        Promise<Int, PromiseTestError>.resolve(1)
            .flatMap { .resolve($0 + 1) }
            .peek { XCTAssertEqual($0, 2) }
            .flatMap { _ in Promise<Int, PromiseTestError>.reject(PromiseTestError()) }
            .peek { _ in XCTFail() }
            .catch { _ in }
            .waitUntilExit(self)
    }
}
