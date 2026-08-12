//
//  File.swift
//  
//
//  Created by yuki on 2023/04/10.
//

import Foundation

final public class YObjectEvent: YEvent {
    public var keysChanged: Set<String?>

    init(_ object: YObject, transaction: YTransaction, keysChanged: Set<String?>) {
        self.keysChanged = keysChanged
        super.init(object, transaction: transaction)
    }
}
