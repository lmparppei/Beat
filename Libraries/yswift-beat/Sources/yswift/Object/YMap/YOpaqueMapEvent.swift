//
//  File.swift
//  
//
//  Created by yuki on 2023/03/29.
//

import Foundation

final public class YOpaqueMapEvent: YEvent {
    public var keysChanged: Set<String?>

    init(_ ymap: YOpaqueMap, transaction: YTransaction, keysChanged: Set<String?>) {
        self.keysChanged = keysChanged
        super.init(ymap, transaction: transaction)
    }
}
