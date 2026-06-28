//
//  File.swift
//
//
//  Created by yuki on 2023/05/27.
//

#if canImport(Combine)
import XCTest
import Combine
import Promise

final class PromisePublisherTests: XCTestCase {
    var objectBag = Set<AnyCancellable>()
    
    func testPublisherPromise_Just() {
        var fulfilled = false
        Just(123).firstValue()
            .sink {
                fulfilled = true
                XCTAssertEqual($0, 123)
            }
        XCTAssert(fulfilled)
    }
    
    func testPublisherPromise_Empty() {
        var fulfilled = false
        Empty<Int, Never>().firstValue()
            .sink {
                fulfilled = true
                XCTAssertEqual($0, nil)
            }
        XCTAssert(fulfilled)
    }
    
    func testPublisherPromise_Combined() {
        var fulfilled = false
        Just(1).combineLatest(Just(2), Just(3))
            .firstValue()
            .tryPeek {
                fulfilled = true
                XCTAssert(try XCTUnwrap($0) == (1, 2, 3))
            }
            .catch { _ in XCTFail() }
        XCTAssert(fulfilled)
    }
    
    func testPromisePublisher() {
        let promise = Promise<Int, Never>()
        
        var value: Int? = nil
        promise.publisher()
            .sink { value = $0 }
            .store(in: &objectBag)
        
        XCTAssertEqual(value, nil)
        promise.resolve(100)
        XCTAssertEqual(value, 100)
    }
    
    func testM() {
        let a: Any.Type
        func isHashable<T>(_ type: T.Type) -> Bool {
            type is (any Hashable).Type
        }
        
        print(isHashable(Int.self)) // true
    }
}

#endif
