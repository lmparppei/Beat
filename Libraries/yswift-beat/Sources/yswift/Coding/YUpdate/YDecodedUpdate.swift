//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation
import lib0

extension YUpdate {
    public func readInfo() throws -> Info {
        try Info(self.data, YDecoder: YUpdateDecoderV1.init)
    }
    public func readInfoV2() throws -> Info {
        try Info(self.data, YDecoder: YUpdateDecoderV2.init)
    }
    
    final public class Info: CustomStringConvertible {
        var structs: [YStructure]
        var deleteSets: YDeleteSet
        
        public var description: String {
            "YDecodedUpdate(structs: \(structs), deleteSets: \(deleteSets))"
        }
                
        fileprivate init(_ update: Data, YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV1.init) throws {
            var structs: [YStructure] = []
            let updateDecoder = try YDecoder(LZDecoder(update))
            let lazyDecoder = try YLazyStructReader(updateDecoder, filterSkips: false)
            var curr = lazyDecoder.curr
            while let ucurr = curr {
                structs.append(ucurr)
                curr = try lazyDecoder.next()
            }
            
            self.structs = structs
            self.deleteSets = try YDeleteSet.decode(decoder: updateDecoder)
        }
    }
    
}
