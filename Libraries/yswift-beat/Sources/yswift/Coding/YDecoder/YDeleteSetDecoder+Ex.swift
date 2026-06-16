//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YDeleteSetDecoder {
    func readStateVector() throws -> [Int: Int] {
        var ss = [Int:Int]()
        let ssLength = try self.restDecoder.readUInt()
        for _ in 0..<ssLength {
            let client = try Int(self.restDecoder.readUInt())
            let clock = try Int(self.restDecoder.readUInt())
            
            ss[client] = clock
        }
        return ss
    }
}
