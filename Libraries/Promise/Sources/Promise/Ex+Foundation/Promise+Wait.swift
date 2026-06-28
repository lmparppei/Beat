//
//  Promise+Wait.swift
//  Promise
//
//  Created by yuki on 2021/08/23.
//

#if canImport(Foundation)
import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {

    /// Converts Foundation’s `Duration` to `TimeInterval` with sub‑second
    /// precision.
    @inlinable var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + Double(attoseconds) * 1e-18
    }
}
 
extension Promise {
    
    /// Delays the *delivery* of the promise’s result by `interval` seconds.
    ///
    /// The work starts immediately; only the *observation* is postponed.
    @inlinable
    public func wait(on queue: DispatchQueue = .main, for interval: TimeInterval) -> Promise<Output, Failure> where Output: Sendable {
        self.receive(on: { queue.asyncAfter(deadline: .now() + interval, execute: $0) })
    }
    
    /// Duration‑based overload.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @inlinable
    public func wait(on queue: DispatchQueue = .main, for duration: Duration) -> Promise<Output, Failure> where Output: Sendable {
        return self.wait(on: queue, for: duration.timeInterval)
    }
    
    // MARK: Static helpers for Void‑Never promises

    /// Returns a promise that fulfills after `interval` seconds.
    @inlinable
    public static func wait(on queue: DispatchQueue = .main, for interval: TimeInterval) -> Promise<Output, Failure> where Output == Void, Failure == Never {
        Promise.resolve().wait(on: queue, for: interval)
    }
    
    /// Duration‑based overload of the above convenience.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @inlinable
    public static func wait(on queue: DispatchQueue = .main, for duration: Duration) -> Promise<Output, Failure> where Output == Void, Failure == Never {
        Promise.resolve().wait(on: queue, for: duration)
    }
}
#endif
