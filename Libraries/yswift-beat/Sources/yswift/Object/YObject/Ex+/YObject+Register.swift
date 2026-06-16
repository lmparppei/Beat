//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    public class func register(_ typeID: UInt) {
        let nTypeID = Int(typeID) + 7
        self.typeIDTable[ObjectIdentifier(self)] = nTypeID
        YObjectContent.register(for: nTypeID) {_ in
            YObject.initContext = .decode
            defer { YObject.initContext = .unspecified }
            return Self()
        }
    }
    
    public class func unregister() {
        guard let typeID = self.typeIDTable[ObjectIdentifier(self)] else { return }
        YObjectContent.unregister(for: typeID)
    }
}
