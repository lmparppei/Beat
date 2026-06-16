import XCTest
import yswift

final class PublicAPITests: XCTestCase {
    func api() {
        class Person: YObject {
            @Property var name = ""
            @Property var age = 0
            
            required init() {
                super.init()
                self.register(_name, for: "name")
                self.register(_age, for: "age")
            }
            
            convenience init(name: String, age: Int) {
                self.init()
                self.name = name
                self.age = age
            }
        }
        
//        let document = YDocument()
//        let root = document.getMap(Person.self, "root")
    }
}
