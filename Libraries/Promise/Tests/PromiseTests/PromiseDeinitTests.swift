//
//  File.swift
//  
//
//  Created by yuki on 2024/05/27.
//

import XCTest
import Promise

final class PromiseDeinitTests: XCTestCase {
    func testDeinit_withoutResolveAndReject() {
        var failed = false
        do {
            let promise = Promise<Void, Error>
                .optionallyResolving { resolve, reject in }
            
            promise.catch { _ in failed = true }
        }
        
        XCTAssertTrue(failed)
    }
    
    func testDeinit_withResolve() {
        var failed = false
        do {
            let promise = Promise<Void, Error>
                .optionallyResolving { resolve, reject in
                    resolve(())
                }
            
            promise.catch { _ in failed = true }
        }
        
        XCTAssertFalse(failed)
    }
    
    func testDeinit_stillAlive() {
        var failed = false
        var resolver: PromiseResolver<Void>?
        
        do {
            let promise = Promise<Void, Error>
                .optionallyResolving { resolve, reject in
                    resolver = resolve
                }
            
            promise.catch { _ in failed = true }
        }
        
        XCTAssertNotNil(resolver)
        XCTAssertFalse(failed)
    }
    
    func testDeinit_allDead() {
        var failed = false
        var resolver: PromiseResolver<Void>?
        var rejector: PromiseRejector<Void>?
        
        do {
            let promise = Promise<Void, Error>
                .optionallyResolving { resolve, reject in
                    resolver = resolve
                    rejector = reject
                }
            
            promise.catch { _ in failed = true }
        }
        
        XCTAssertNotNil(resolver)
        XCTAssertNotNil(rejector)
        
        XCTAssertFalse(failed)
        
        resolver = nil
        
        XCTAssertFalse(failed)
        
        rejector = nil
        
        XCTAssertTrue(failed)
    }
}
