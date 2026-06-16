//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class Backtrace: CustomStringConvertible {
    final class Symbol: CustomStringConvertible {
        let moduleName: String
        let address: String
        let mangledName: String
        let offset: Int?
        lazy var symbolName = Demangler.humanReadableDemangle(self.mangledName)
        
        var description: String {
            "\(moduleName)\t\t\t\(symbolName)"
        }
        
        init(_ symbol: String) {
            let components = symbol
                .components(separatedBy: .whitespaces)
                .filter{ !$0.isEmpty }
                        
            self.moduleName = components[1].replacingOccurrences(of: ".dylib", with: "")
            self.address = components[2]
            self.mangledName = components[3..<components.count-2].joined(separator: " ")
            self.offset = Int(components[5])
        }
    }
    
    private let symbols: [Backtrace.Symbol]
    private var omitSymbolCount: Int
    static let testing: Bool = NSClassFromString("XCTest") != nil
    
    var description: String {
        let symbolList = symbols
            .enumerated()
            .map{ "\($0)\t\($1.description)" }
            .joined(separator: "\n")

        return "\(symbolList)\n...omitting \(omitSymbolCount) symbols."
        
    }
    
    init(dropFirstSymbols: Int = 0) {
        let symbols = Thread.callStackSymbols
            .map{ Backtrace.Symbol($0) }
            .dropFirst(2 + dropFirstSymbols)
                
        if Backtrace.testing {
            var nsymbols = [Symbol]()
            for symbol in symbols {
                if symbol.moduleName == "XCTestCore" { break }
                nsymbols.append(symbol)
            }
            self.symbols = nsymbols
            self.omitSymbolCount = symbols.count - nsymbols.count
        } else {
            self.symbols = symbols.map{ $0 }
            self.omitSymbolCount = 0
        }
    }
}

fileprivate enum Demangler {
    static func demangle(_ mangledName: String) -> String {
        mangledName.utf8CString.withUnsafeBufferPointer { str in
            guard let namePtr = _demangle(mangledName: str.baseAddress, length: UInt(str.count-1)) else {
                return mangledName
            }
            defer { namePtr.deallocate() }
            return String(cString: namePtr)
        }
    }
    
    static func humanReadableDemangle(_ mangledName: String) -> String {
        demangle(mangledName)
            .replacingOccurrences(of: "Swift.", with: "")
            .replacingOccurrences(of: "yswift.", with: "")
            .replacingOccurrences(of: "@owned ", with: "")
            .replacingOccurrences(of: "@unowned ", with: "")
            .replacingOccurrences(of: "@error ", with: "")
            .replacingOccurrences(of: "@callee_guaranteed ", with: "")
            .replacingOccurrences(of: "@in_guaranteed ", with: "")
            .replacingOccurrences(of: "@in_guaranteed ", with: "")
    }

    @_silgen_name("swift_demangle")
    private static func _demangle(
        mangledName: UnsafePointer<CChar>?, length: UInt,
        _: Int? = nil, _: Int? = nil, _: UInt32 = 0
    ) -> UnsafeMutablePointer<CChar>?
}
