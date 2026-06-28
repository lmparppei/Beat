//
//  Promise+Timeout.swift
//  Promise
//
//  Created by yuki on 2022/01/27.
//

#if canImport(Foundation)
import Foundation

/// Error thrown when a promise fails to settle within the specified interval.
public struct PromiseTimeoutError: Error, LocalizedError, CustomStringConvertible {
    @inlinable public var description: String { "Promise has timed out." }
    
    @inlinable init() {}
}

extension Promise where Output: Sendable {
    
    /// Fails the promise with `PromiseTimeoutError` if it does not resolve
    /// within `interval` seconds.
    @inlinable
    public func timeout(_ interval: TimeInterval, on queue: DispatchQueue = .main) -> Promise<Output, Error> {
        self.timeout(interval, error: PromiseTimeoutError(), on: queue)
    }
    
    /// General‑purpose timeout that allows you to supply a custom error.
    @inlinable
    public func timeout<T: Error>(_ interval: TimeInterval, error: @Sendable @autoclosure @escaping () -> T, on queue: DispatchQueue = .main) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe(promise.resolve, promise.reject)
            
        queue.asyncAfter(deadline: .now() + interval) {
            promise.reject(error())
        }
        
        return promise
    }
    
    // MARK: Duration‑based overloads (Swift 5.7)
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @inlinable public func timeout(_ duration: Duration, on queue: DispatchQueue = .main) -> Promise<Output, Error> {
        self.timeout(duration.timeInterval, error: PromiseTimeoutError(), on: queue)
    }
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @inlinable public func timeout<T: Error>(_ duration: Duration, error: @Sendable @autoclosure @escaping () -> T, on queue: DispatchQueue = .main) -> Promise<Output, Error> {
        self.timeout(duration.timeInterval, error: error(), on: queue)
    }
}
#endif
