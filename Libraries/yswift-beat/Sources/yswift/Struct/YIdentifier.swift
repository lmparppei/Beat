//
//  YID.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

final public class YIdentifier: Equatable {
    /// Client id
    var client: Int
    /// unique per client id, continuous Int */
    var clock: Int

    init(client: Int, clock: Int) {
        self.client = client
        self.clock = clock
    }

    func encode(_ encoder: LZEncoder) {
        encoder.writeUInt(UInt(self.client))
        encoder.writeUInt(UInt(self.clock))
    }

    static func decode(_ decoder: LZDecoder) throws -> YIdentifier {
        return YIdentifier(
            client: Int(try decoder.readUInt()),
            clock: Int(try decoder.readUInt())
        )
    }
    
    public static func == (lhs: YIdentifier, rhs: YIdentifier) -> Bool {
        return lhs.client == rhs.client && lhs.clock == rhs.clock
    }
}
