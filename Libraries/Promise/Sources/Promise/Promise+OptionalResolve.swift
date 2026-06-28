//
//  Promise+OptionalResolve.swift
//
//
//  Created by yuki on 2024/05/27.
//

/// Error whose presence means a promise escaped without ever being fulfilled
/// or rejected.
///
/// `PromiseUnresolveError` is injected automatically by the library when a
/// promise deallocates in the *pending* state.  Treat this as a programmer‑
/// error: it usually indicates you forgot to settle, cancel, or otherwise
/// chain the promise.
///
/// The type conforms to `LocalizedError` (when Foundation is available) so the
/// message is surfaced nicely in Cocoa error dialogs.
public struct PromiseUnresolveError: Error, CustomStringConvertible {
    /// Textual description used for `debugDescription`,
    /// `errorDescription`, and `String(describing:)`.
    @inlinable public var description: String { "Promise has not been resolved." }
    
    @inlinable init() {}
}

#if canImport(Foundation)
import Foundation

extension PromiseUnresolveError: LocalizedError {
    @inlinable public var errorDescription: String? { self.description }
}
#endif

// MARK: - Optional resolution helpers

extension Promise where Failure == Error {
    /// Creates an *unresolved* promise together with strongly‑typed “one‑shot”
    /// resolver and rejector objects.
    ///
    /// Use this when you must hand the settling closures into APIs that store
    /// them weakly or when you need to separate resolve / reject capabilities
    /// across different scopes.
    ///
    /// If **neither** the resolver **nor** the rejector is invoked by the time
    /// *both* leave scope, `PromiseUnresolveError` is raised automatically.
    ///
    /// - Returns: A tuple consisting of the newly created promise and its
    ///   paired resolver/rejector.
    @inlinable
    public static func optionallyResolving() -> (promise: Promise<Output, Failure>, resolver: PromiseResolver<Output>, rejector: PromiseRejector<Output>) {
        let promise = Promise<Output, Error>()
        
        let observer = PromiseObserver(promise: promise)
        let resolver = PromiseResolver(promise: promise, observer: observer)
        let rejector = PromiseRejector(promise: promise, observer: observer)
        
        return (promise, resolver, rejector)
    }
    
    /// Same as ``optionallyResolving()`` but executes `handler`
    /// synchronously to wire‑up your business logic.
    ///
    /// - Parameter handler: Closure where you trigger either
    ///   `resolver(output)` or `rejector(error)`.
    @inlinable
    public static func optionallyResolving(@_implicitSelfCapture _ handler: (PromiseResolver<Output>, PromiseRejector<Output>) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Error>()
        
        let observer = PromiseObserver(promise: promise)
        let resolver = PromiseResolver(promise: promise, observer: observer)
        let rejector = PromiseRejector(promise: promise, observer: observer)
        
        handler(resolver, rejector)
        
        return promise
    }
    
    /// Throwing variant of ``optionallyResolving(_:)`` that converts thrown
    /// errors into rejections automatically.
    @inlinable
    public static func optionallyResolving(@_implicitSelfCapture _ handler: (PromiseResolver<Output>, PromiseRejector<Output>) throws -> ()) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Error>()
        
        let observer = PromiseObserver(promise: promise)
        let resolver = PromiseResolver(promise: promise, observer: observer)
        let rejector = PromiseRejector(promise: promise, observer: observer)
        
        do {
            try handler(resolver, rejector)
        } catch {
            promise.reject(error)
        }
        
        return promise
    }
}

// MARK: - Helper objects

/// Internal RAII guard that injects `PromiseUnresolveError` at deinit if the
/// promise is still unsatisfied.

@usableFromInline
final class PromiseObserver<Output> {
    @usableFromInline let promise: Promise<Output, Error>
    
    @inlinable init(promise: Promise<Output, Error>) {
        self.promise = promise
    }
    
    @inlinable deinit {
        self.promise.reject(PromiseUnresolveError())
    }
}

/// Strongly‑typed wrapper that can *only* resolve its associated promise.
public final class PromiseResolver<Output> {
    @usableFromInline let promise: Promise<Output, Error>
    
    @usableFromInline let observer: PromiseObserver<Output>
    
    @inlinable
    init(promise: Promise<Output, Error>, observer: PromiseObserver<Output>) {
        self.promise = promise
        self.observer = observer
    }
    
    /// Fulfills the promise with `output`.  Subsequent calls are ignored.
    @inlinable
    public final func callAsFunction(_ output: Output) {
        self.promise.resolve(output)
    }
}

/// Strongly‑typed wrapper that can *only* reject its associated promise.
public final class PromiseRejector<Output> {
    @usableFromInline let promise: Promise<Output, Error>
    
    @usableFromInline let observer: PromiseObserver<Output>
    
    @inlinable
    init(promise: Promise<Output, Error>, observer: PromiseObserver<Output>) {
        self.promise = promise
        self.observer = observer
    }
    
    /// Rejects the promise with `failure`.  Further invocations are no‑ops.
    @inlinable
    public final func callAsFunction(_ failure: Error) {
        self.promise.reject(failure)
    }
}

// Swift Concurrency Support

extension PromiseObserver: Sendable where Output: Sendable {}
extension PromiseResolver: Sendable where Output: Sendable {}
extension PromiseRejector: Sendable where Output: Sendable {}
