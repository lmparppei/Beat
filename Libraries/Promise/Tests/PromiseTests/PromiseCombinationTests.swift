import XCTest
import Promise

final class PromiseCombinationTests: XCTestCase {
    func testCombine_resultToBeTuple() {
        Promise<(Int, Int), Never>.combine(
            Promise<Int, Never>.resolve(1),
            Promise<Int, Never>.resolve(2)
        )
        .peek {
            XCTAssertEqual($0.0, 1)
            XCTAssertEqual($0.1, 2)
        }
        .waitUntilExit(self)
    }
    
    func testCombine_FromMultithread() {
        let promiseA = Promise<Int, Never>()
        let promiseB = Promise<Int, Never>()
        let promiseC = Promise<Int, Never>()
        let promiseD = Promise<Int, Never>()
        
        DispatchQueue.global().async { promiseA.resolve(1) }
        DispatchQueue.global().async { promiseB.resolve(2) }
        DispatchQueue.global().async { promiseC.resolve(3) }
        DispatchQueue.global().async { promiseD.resolve(4) }
        
        Promise<(Int, Int), Never>
            .combine(promiseA, promiseB, promiseC, promiseD)
            .peek {
                XCTAssertEqual($0.0, 1)
                XCTAssertEqual($0.1, 2)
                XCTAssertEqual($0.2, 3)
                XCTAssertEqual($0.3, 4)
            }
            .waitUntilExit(self)
    }
    
    func testCombine_arrayMergeAll() {
        let promises = [
            Promise<Int, Never>.resolve(1),
            Promise<Int, Never>.resolve(2),
            Promise<Int, Never>.resolve(3),
            Promise<Int, Never>.resolve(4),
        ]
        
        promises.mergeAll()
            .peek { value in
                XCTAssertEqual(value, 1)
            }
            .waitUntilExit(self)
    }
    
    func testCombine_arrayMergeAll_fromMultithread() {
        let promises = [
            Promise<Int, Never>.dispatch { 1 },
            Promise<Int, Never>.dispatch { 2 },
            Promise<Int, Never>.dispatch { 3 },
            Promise<Int, Never>.dispatch { 4 },
        ]
        
        promises.mergeAll()
            .peek { value in
                XCTAssertTrue([1, 2, 3, 4].contains(value))
            }
            .waitUntilExit(self)
    }
    
    func testCombine_arrayCombineAll() {
        let promises = [
            Promise<Int, Never>.resolve(1),
            Promise<Int, Never>.resolve(2),
            Promise<Int, Never>.resolve(3),
            Promise<Int, Never>.resolve(4),
        ]
        
        promises.combineAll()
            .peek { value in
                XCTAssertEqual(value, [1, 2, 3, 4])
            }
            .waitUntilExit(self)
    }
    
    func testCombine_arrayCombineAll_fromMultithread() {
        let promises = [
            Promise<Int, Never>.dispatch { 1 },
            Promise<Int, Never>.dispatch { 2 },
            Promise<Int, Never>.dispatch { 3 },
            Promise<Int, Never>.dispatch { 4 },
        ]
        
        promises.combineAll()
            .peek { value in
                XCTAssertEqual(value, [1, 2, 3, 4])
            }
            .waitUntilExit(self)
    }
}
