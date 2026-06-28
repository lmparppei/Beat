//
//  Promise+MeasureInterval.swift
//  Promise
//
//  Created by yuki on 2023/06/04.
//

#if canImport(Foundation)
import Foundation

extension Promise {
    
    /// Prints the time elapsed between subscription and settlement using
    /// `Swift.print`.
    ///
    /// - Parameter prefix: Optional prefix to distinguish multiple timers.
    @inlinable public func measureInterval(_ prefix: String = "") -> Promise<Output, Failure> {
        var target = PrintTarget()
        return self.measureInterval(prefix, to: &target)
    }
        
    /// Streams timing information to a custom `TextOutputStream`.
    @inlinable
    public func measureInterval<Target: TextOutputStream>(_ prefix: String = "", to target: inout Target) -> Promise<Output, Failure> {
        var target = target
        let prefix = prefix.isEmpty ? "" : "\(prefix): "
        let startDate = Date()
        
        self.subscribe({ output in
            let timeInterval = Date().timeIntervalSince(startDate)
            target.write("\(prefix)receive output: [\(timeInterval)s] (\(output))")
        }, { failure in
            let timeInterval = Date().timeIntervalSince(startDate)
            target.write("\(prefix)receive failure: [\(timeInterval)s] (\(failure))")
        })
        
        return self
    }
    
    /// Calls the supplied closures with the elapsed interval on settlement.
    @inlinable
    public func measureInterval(@_implicitSelfCapture _ receiveOutput: @escaping (TimeInterval) -> (), @_implicitSelfCapture _ receiveFailure: @escaping (TimeInterval) -> ()) -> Promise<Output, Failure> {
        let startDate = Date()
        
        self.subscribe({ _ in
            receiveOutput(Date().timeIntervalSince(startDate))
        }, { _ in
            receiveFailure(Date().timeIntervalSince(startDate))
        })
        
        return self
    }
    
    /// Output‑only variant for promises that never fail.
    @inlinable
    public func measureInterval(@_implicitSelfCapture _ receiveOutput: @escaping (TimeInterval) -> ()) -> Promise<Output, Failure> where Failure == Never {
        let startDate = Date()
        
        self.subscribe({ _ in
            receiveOutput(Date().timeIntervalSince(startDate))
        }, { _ in })
        
        return self
    }
}
#endif

