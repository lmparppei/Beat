//
//  Promise+GCD.swift
//  Promise
//
//  Created by yuki on 2021/08/07.
//

#if canImport(Foundation)
import Foundation

extension Promise where Output: Sendable {
    
    /// Executes `handler` asynchronously on `queue`, wiring its callbacks into
    /// a new promise.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue on which the work should run
    ///            (default: global concurrent).
    ///   - handler: Closure receiving the promise’s `resolve` and `reject`.
    @inlinable
    public static func dispatch(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ handler: @Sendable @escaping (@escaping (Output) -> (), @escaping (Failure) -> ()) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        queue.async { handler(promise.resolve, promise.reject) }
        return promise
    }
    
    /// Convenience overload for *non‑throwing*, non‑failable work.
    @inlinable
    public static func dispatch(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ output: @Sendable @escaping () -> Output) -> Promise<Output, Failure> where Failure == Never {
        let promise = Promise<Output, Failure>()
        queue.async { promise.resolve(output()) }
        return promise
    }
        
    /// Same as ``dispatch(on:_:)-(_,((Output)->(),(Failure)->())->())`` but the handler may `throw`.
    @inlinable
    public static func tryDispatch(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ handler: @Sendable @escaping (@escaping (Output) -> (), @escaping (Failure) -> ()) throws -> ()) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Failure>()
        queue.async { do { try handler(promise.resolve, promise.reject) } catch { promise.reject(error) } }
        return promise
    }
    
    /// `throw`ing overload where the result comes from the closure’s return
    /// value.
    @inlinable
    public static func tryDispatch(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ output: @Sendable @escaping () throws -> Output) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Failure>()
        queue.async { do { promise.resolve(try output()) } catch { promise.reject(error) } }
        return promise
    }
    
    /// Re‑emits the promise’s settlement on the supplied queue.
    @inlinable
    public func receive(on queue: DispatchQueue) -> Promise<Output, Failure> {
        self.receive(on: { queue.async(execute: $0) })
    }
}

// Unsafe GCD variants (macOS 14 / iOS 17)

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension Promise {
    
    /// Same as ``dispatch(on:_:)-(_,((Output)->(),(Failure)->())->())`` but uses `queue.asyncUnsafe`.
    @inlinable
    public static func dispatchUnsafe(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ handler: @Sendable @escaping (@escaping (Output) -> (), @escaping (Failure) -> ()) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        queue.asyncUnsafe { handler(promise.resolve, promise.reject) }
        return promise
    }
    
    /// Non‑throwing, non‑failable overload of `dispatchUnsafe`.
    @inlinable
    public static func dispatchUnsafe(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ output: @Sendable @escaping () -> Output) -> Promise<Output, Failure> where Failure == Never {
        let promise = Promise<Output, Failure>()
        queue.asyncUnsafe { promise.resolve(output()) }
        return promise
    }
     
    /// Throwing overload of `dispatchUnsafe`.
    @inlinable
    public static func tryDispatchUnsafe(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ handler: @Sendable @escaping (@escaping (Output) -> (), @escaping (Failure) -> ()) throws -> ()) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Failure>()
        queue.asyncUnsafe { do { try handler(promise.resolve, promise.reject) } catch { promise.reject(error) } }
        return promise
    }
    
    /// Throwing overload returning a value.
    @inlinable
    public static func tryDispatchUnsafe(on queue: DispatchQueue = .global(), @_implicitSelfCapture _ output: @Sendable @escaping () throws -> Output) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Failure>()
        queue.asyncUnsafe { do { promise.resolve(try output()) } catch { promise.reject(error) } }
        return promise
    }
    
    /// Re‑emits settlement using `queue.asyncUnsafe`.
    @inlinable
    public func receiveUnsafe(on queue: DispatchQueue) -> Promise<Output, Failure> {
        self.receiveUnsafe(on: { queue.asyncUnsafe(execute: $0) })
    }
}
#endif
