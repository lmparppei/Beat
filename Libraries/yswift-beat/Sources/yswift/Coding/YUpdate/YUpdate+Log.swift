//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import lib0

#if DEBUG
extension YUpdate {
    public func log() {
        switch self.version {
        case .v1: self._logUpdate(YDecoder: YUpdateDecoderV1.init)
        case .v2: self._logUpdate(YDecoder: YUpdateDecoderV2.init)
        }
    }

    private func _logUpdate(YDecoder: (LZDecoder) throws -> YUpdateDecoder) {
        do {
            var structs: [YStructure] = []
            let updateDecoder = try YDecoder(LZDecoder(self.data))
            let lazyDecoder = try YLazyStructReader(updateDecoder, filterSkips: false)
            
            var curr = lazyDecoder.curr; while curr != nil {
                structs.append(curr!)
                curr = try lazyDecoder.next()
            }
            print("Structs: \(structs)")
            let ds = try YDeleteSet.decode(decoder: updateDecoder)
            print("DeleteSet: \(ds)")
        } catch {
            print(error)
        }
    }

}
#endif
