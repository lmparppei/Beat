import XCTest
import Promise
import yswift
import Combine

final class YAwarenessTests: XCTestCase {
    struct Cursor: Codable {
        let name: String
        var position: CGPoint
    }
    
    func testAwareness_Basic() throws {
        let test = YAwarenessTest<String>(count: 2)
        
        let awareness0 = test.awarenesses[0]
        let awareness1 = test.awarenesses[1]
        
        awareness0.localState = "Client 0"
        awareness1.localState = "Client 1"
                
        test.sync()
        
        print(awareness0.states)
        print(awareness1.states)
    }
        
    func testAwarenessSync() throws {
        let test = YAwarenessTest<Cursor>(count: 2)
        
        let awareness0 = test.awarenesses[0]
        let awareness1 = test.awarenesses[1]
        
        awareness0.localState = Cursor(name: "Alice", position: CGPoint(x: 10, y: 10))
                
        test.sync()
        
        XCTAssertEqual(awareness1.states.values.first?.name, "Alice")
        XCTAssertEqual(awareness1.states.values.first?.position, CGPoint(x: 10, y: 10))
    }
    
    func testAwarenessSyncBidirectional() throws {
        let test = YAwarenessTest<Cursor>(count: 2)
        
        let awareness0 = test.awarenesses[0]
        let awareness1 = test.awarenesses[1]
        
        awareness0.localState = Cursor(name: "Alice", position: CGPoint(x: 10, y: 10))
        awareness1.localState = Cursor(name: "Bob", position: CGPoint(x: 20, y: 20))
        
        test.sync()
        
        XCTAssertEqual(awareness0.states[test.docs[0].clientID]?.name, "Alice")
        XCTAssertEqual(awareness0.states[test.docs[1].clientID]?.name, "Bob")
        
        XCTAssertEqual(awareness1.states[test.docs[0].clientID]?.name, "Alice")
        XCTAssertEqual(awareness1.states[test.docs[1].clientID]?.name, "Bob")
    }
    
    func testAwarenessSyncPublisher() throws {
        let test = YAwarenessTest<Cursor>(count: 2)
        
        let awareness0 = test.awarenesses[0]
        let awareness1 = test.awarenesses[1]
        
        awareness0.localState = Cursor(name: "Alice", position: CGPoint(x: 10, y: 10))
        awareness1.updatePublisher
            .sink{ print($0) }.store(in: &objectBag)
        
        test.sync()
    }
}

final class YAwarenessTest<State: Codable> {
    let awarenesses: [YAwareness<State>]
    let docs: [YDocument]
    
    private var objectBag = [AnyCancellable]()
    private var messages = [Data]()
    
    func sync() {
        for update in messages {
            for a in awarenesses {
                a.applyUpdate(update, origin: .custom("test"))
            }
        }
    }
    
    init(count: Int) {
        var awarenesses = [YAwareness<State>]()
        var documents = [YDocument]()
        for _ in 0..<count {
            let document = YDocument()
            let awareness = YAwareness<State>()
            awareness.register(document)
            awarenesses.append(awareness)
            documents.append(document)
        }
        self.awarenesses = awarenesses
        self.docs = documents
        
        
        for awareness in self.awarenesses {
            awareness.updatePublisher
                .sink{ (update, origin) in
                    guard case .local = origin,
                          let update = awareness.encodeUpdate(of: update.changed.map{ $0 })
                    else { return }
                    
                    self.messages.append(update)
                }
                .store(in: &objectBag)
        }
    }
}
