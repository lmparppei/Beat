//
//  File.swift
//  
//
//  Created by yuki on 2023/03/29.
//

import Foundation

final class YOpaqueArrayEvent: YEvent {
    var _transaction: YTransaction

    init(_ yarray: YOpaqueArray, transaction: YTransaction) {
        self._transaction = transaction
        super.init(yarray, transaction: transaction)
    }
}
