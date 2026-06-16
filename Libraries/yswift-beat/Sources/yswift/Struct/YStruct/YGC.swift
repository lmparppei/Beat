//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class YGC: YStructure {
    static let refID: UInt8 = 0
    
    override var deleted: Bool { true }

    override func merge(with right: YStructure) -> Bool {
        guard let gc = right as? YGC else { return false }
        self.length += gc.length
        return true
    }

    override func integrate(transaction: YTransaction, offset: Int) {
        if offset > 0 {
            self.id.clock += offset
            self.length -= offset
        }
        transaction.doc.store.addStruct(self)
    }

    override func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeInfo(YGC.refID)
        encoder.writeLen(self.length - offset)
    }
}

