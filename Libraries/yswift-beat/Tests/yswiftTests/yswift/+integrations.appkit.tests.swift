import XCTest
import Promise
import Combine
@testable import yswift

#if canImport(AppKit)

extension NSPasteboard.ObjectType where T == Person {
    static var person: Self { "com.yswifttest.person" }
}

final class AppKitIntegrationsTests: XCTestCase {
    override func setUp() async throws {
        Person.registerAuto()
    }
    
    func testPasteboardObjectReference() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Person.self, 0)
        
        let alice = Person(name: "Alice", age: 16)
        map0["alice"] = alice
        
        NSPasteboard.general.declareType(.person, owner: self)
        NSPasteboard.general.prepareForNewContents()
        NSPasteboard.general.setObjectsRef([alice], forType: .person)
        
        let alicer = try XCTUnwrap(NSPasteboard.general.objects(type: .person)?.first)
        
        XCTAssertEqualReference(alice, alicer)
    }
    
    func testPasteboardObjectCopy() throws {
        let test = try YTest<Any>(docs: 1)
        let map0 = test.swiftyMap(Person.self, 0)
        
        let alice = Person(name: "Alice", age: 16)
        map0["alice"] = alice
        
        NSPasteboard.general.declareType(.person, owner: self)
        NSPasteboard.general.prepareForNewContents()
        NSPasteboard.general.setObjects([alice], forType: .person)
        
        let alicer = try XCTUnwrap(NSPasteboard.general.objects(type: .person)?.first)
        
        XCTAssertNotEqual(alice.objectID, alicer.objectID)
    }
}

#endif
