import XCTest
import Promise

final class PromiseMultithreadTests: XCTestCase {
    func testPromiseThreadMove_withAsync() {
        let end = expectation(description: "")
        
        XCTAssert(Thread.isMainThread)
                
        Promise.detached {
            _ = await Promise<Int, Never>.resolve(1).value
        }
        .peek { XCTAssert(!Thread.isMainThread) }
        .receive(on: .main)
        .peek { XCTAssert(Thread.isMainThread) }
        .receive(on: .global())
        .peek { XCTAssert(!Thread.isMainThread) }
        .finally{ end.fulfill() }
        
        wait(for: [end], timeout: 1)
    }

    func testPromiseThreadMove() {
        let end = expectation(description: "")
        
        XCTAssert(Thread.isMainThread)
        
        Promise.detached {
            _ = await Promise<Int, Never>.resolve(1).value
        }
        .peek { XCTAssert(!Thread.isMainThread) }
        .receive(on: .main)
        .peek { XCTAssert(Thread.isMainThread) }
        .receive(on: .global())
        .peek { XCTAssert(!Thread.isMainThread) }
        .finally{ end.fulfill() }
        
        wait(for: [end], timeout: 1)
    }
    
    func testMultithreadCombine() {
        let N = 1000
        let end = expectation(description: "")
        let promises = (0..<N).map { _ in Promise<Int, Never>() }
        
        for i in 0..<N {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                promises[i].resolve(i)
            }
        }
        
        promises.combineAll()
            .sink {
                XCTAssertEqual($0, (0..<N).map{ $0 })
                end.fulfill()
            }
        
        wait(for: [end], timeout: 0.1)
    }
    
    func testMultithreadCombine_2() {
        let end = expectation(description: "")
        
        let promises = (0..<4).map { _ in Promise<Int, Never>() }
        
        for i in 0..<4 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                promises[i].resolve(i)
            }
        }
        
        let res = Promise<Int, Never>.combine(promises[0], promises[1], promises[2], promises[3])
        
        res.sink {
            XCTAssert($0 == (0, 1, 2, 3))
            end.fulfill()
        }
        
        
        wait(for: [end], timeout: 0.1)
    }
    
    
    func testMultithreadMerge() {
        let end = expectation(description: "")
        
        let promises = (0..<100).map { _ in Promise<Int, Never>() }
        
        for i in 0..<100 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                promises[i].resolve(i)
            }
        }
        
        var caller = 0
        promises.mergeAll()
            .sink{_ in caller += 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            XCTAssertEqual(caller, 1)
            end.fulfill()
        }
        
        wait(for: [end])
    }
    
    func testMayDeadLock() {
        let end = expectation(description: "")
        let promise = Promise<Int, Never>()
        
        promise
            .sink{ promise.resolve($0); end.fulfill() }
        
        promise.resolve(1)
        
        wait(for: [end])
    }
    
    func testDispatchWorks() {
        let end = expectation(description: "")
        let promise = Promise<Int, Never>()
        
        var caller = 0
        promise.sink { _ in caller += 1 }
        
        for i in 0..<100 {
            DispatchQueue.global().asyncAfter(deadline: .now()+0.01) {
                promise.resolve(i)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            XCTAssertEqual(caller, 1)
            end.fulfill()
        }
        
        wait(for: [end])
    }
}
