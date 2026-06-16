//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

final class YObjectStore {
    
    static let shared = YObjectStore()
    
    private var objectTable = [YObjectID: YObject]()
    
    func register(_ object: YObject) {
        guard let id = object.objectID else {
            assertionFailure("This object has no objectID yet.")
            return
        }
        
        self.objectTable[id] = object
    }
    
    func object(for id: YObjectID) -> YObject {
        return self.objectTable[id]!
    }
}
