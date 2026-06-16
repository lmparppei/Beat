//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class YSkip: YStructure {
    static let refID: UInt8 = 10

    override var deleted: Bool { true }

    func mergeWith(_ right: YStructure) -> Bool {
        guard let skip = right as? YSkip else { return false }
        self.length += skip.length
        return true
    }

    override func integrate(transaction: YTransaction, offset: Int) throws {
        throw YSwiftError.unexpectedCase
    }

    override func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeInfo(YSkip.refID)
        encoder.restEncoder.writeUInt(UInt(self.length - offset))
    }
}
