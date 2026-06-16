//
//  YSwiftError.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public struct YSwiftError: LocalizedError, CustomStringConvertible {
    static let unexpectedCase = YSwiftError("Unexpected Case.")
    static let unexpectedContentType = YSwiftError("Unexpected Case.")
    static let lengthExceeded = YSwiftError("Unexpected Content Type.")
    static let integretyCheckFail = YSwiftError("Integrety Check Fail")
    static let originDocGC = YSwiftError("origin Doc must not be garbage collected")
    
    let message: String
    let backtrace: Backtrace
    
    public var description: String { "\(message)\n\(backtrace)" }
    
    init(_ message: String) {
        self.message = message
        self.backtrace = Backtrace(dropFirstSymbols: 1)
    }
}
