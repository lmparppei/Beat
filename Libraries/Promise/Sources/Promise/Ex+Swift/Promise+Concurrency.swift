//
//  Promise+Concurrency.swift
//  Promise
//
//  Created by yuki on 2023/03/17.
//

extension Promise: @unchecked Sendable where Output: Sendable, Failure: Sendable {}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Promise where Output: Sendable, Failure == Never {
    /// Awaits the fulfilled value of a *non‑failable* promise.
    ///
    /// The property suspends until the promise resolves, then returns the
    /// captured `Output`.
    ///
    /// ```swift
    /// let image = await imagePromise.value   // cannot throw
    /// ```
    @inlinable public var value: Output {
        @inlinable get async {
            #if DEBUG
            await withCheckedContinuation { continuation in
                self.subscribe({ continuation.resume(returning: $0) }, { _ in })
            }
            #else
            await withUnsafeContinuation { continuation in
                self.subscribe({ continuation.resume(returning: $0) }, { _ in })
            }
            #endif
        }
    }

    /// Wraps an `async` task that *cannot* fail in a promise.
    ///
    /// The task starts immediately at the supplied `priority`.  If the promise
    /// is cancelled upstream, the underlying task is cancelled automatically.
    @inlinable
    public convenience init(
        priority: TaskPriority? = nil,
        @_inheritActorContext @_implicitSelfCapture _ task: @Sendable @escaping () async -> Output
    ) {
        self.init()
        let task = Task(priority: priority) { self.resolve(await task()) }
        self.subscribe({ _ in task.cancel() }, { _ in })
    }
    
    /// Detached version of ``init(priority:_:)-9h0r8``.
    @inlinable
    public static func detached(
        priority: TaskPriority? = nil,
        @_inheritActorContext @_implicitSelfCapture _ task: @Sendable @escaping () async -> Output
    ) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        let task = Task.detached(priority: priority) { promise.resolve(await task()) }
        promise.subscribe({ _ in task.cancel() }, { _ in })
        return promise
    }
    
    /// Asynchronously consumes the promise’s value.
    ///
    /// - Parameter receiveOutput: `async` closure executed on fulfillment.
    ///   Failure is ignored because `Failure == Never`.
    @inlinable
    public func asink(
        _ receiveOutput: @Sendable @escaping (Output) async -> Void
    ) {
        self.subscribe({ output in
            Task { await receiveOutput(output) }
        }, { _ in })
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Promise where Output: Sendable {
    /// Awaits the result of a *fallible* promise, throwing on rejection.
    @inlinable public var value: Output {
        @inlinable get async throws {
            #if DEBUG
            try await withCheckedThrowingContinuation { continuation in
                self.subscribe({ continuation.resume(returning: $0) }, continuation.resume(throwing:))
            }
            #else
            try await withUnsafeThrowingContinuation { continuation in
                self.subscribe({ continuation.resume(returning: $0) }, continuation.resume(throwing:))
            }
            #endif
        }
    }
    
    /// Convenience initializer that feeds async work into the promise.
    @inlinable
    public convenience init(
        @_implicitSelfCapture _ handler: (@Sendable @escaping (Output) -> (), @Sendable @escaping (Failure) -> ()) -> ()
    ) {
        self.init()
        handler(self.resolve, self.reject)
    }
    
    /// Async task wrapper for promises that may throw (`Failure == Error`).
    @inlinable
    public convenience init(
        priority: TaskPriority? = nil,
        @_inheritActorContext @_implicitSelfCapture _ task: @Sendable @escaping () async throws -> Output
    ) where Failure == Error {
        self.init()
        let task = Task(priority: priority) { do { self.resolve(try await task()) } catch { self.reject(error) } }
        self.subscribe({ _ in task.cancel() }, { _ in task.cancel() })
    }
    
    /// Detached variant of the above.
    @inlinable
    public static func detached(
        priority: TaskPriority? = nil,
        @_inheritActorContext @_implicitSelfCapture _ task: @Sendable @escaping () async throws -> Output
    ) -> Promise<Output, Failure> where Failure == Error {
        let promise = Promise<Output, Failure>()
        let task = Task.detached(priority: priority) { do { promise.resolve(try await task()) } catch { promise.reject(error) } }
        promise.subscribe({ _ in task.cancel() }, { _ in task.cancel() })
        return promise
    }
    
    // MARK: Async sinks

    /// Consumes both success and failure using `async` receivers.
    @inlinable
    public func asink(
        @_implicitSelfCapture _ receiveOutput: @Sendable @escaping (Output) async -> Void,
        @_implicitSelfCapture _ receiveFailure: @Sendable @escaping (Failure) async -> Void
    ) {
        self.subscribe({ output in
            Task { await receiveOutput(output) }
        }, { error in
            Task { await receiveFailure(error) }
        })
    }
    
    /// Fulfillment‑only async tap; ignores errors.
    @inlinable
    public func apeek(
        @_implicitSelfCapture _ receiveOutput: @Sendable @escaping (Output) async -> Void
    ) {
        self.subscribe({ output in
            Task { await receiveOutput(output) }
        }, { _ in })
    }
    
    /// Failure‑only async tap; ignores successes.
    @inlinable
    public func apeekError(
        @_implicitSelfCapture _ receiveFailure: @Sendable @escaping (Failure) async -> Void
    ) {
        self.subscribe({ _ in }, { error in
            Task { await receiveFailure(error) }
        })
    }
    
    /// Delivers the promise’s settlement onto a custom callback
    /// ‑‑ useful for bridging to actor executors or other frameworks.
    ///
    /// The callback receives a **thunk** which *must* be executed to continue
    /// the chain.
    @inlinable
    public func receive(@_implicitSelfCapture on callback: @escaping (@Sendable @escaping () -> ()) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        self.subscribe({ output in
            callback{ promise.resolve(output) }
        }, { failure in
            callback{ promise.reject(failure) }
        })
        return promise
    }
}

// MARK: Unsafe (non‑Sendable) receive

extension Promise {
    /// Same as `receive(on:)` but accepts ordinary escaping closures that are
    /// *not* `Sendable`.  Use only when you must interact with legacy code.
    @inlinable
    public func receiveUnsafe(@_implicitSelfCapture on callback: @escaping (@escaping () -> ()) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        self.subscribe({ output in
            callback { promise.resolve(output) }
        }, { failure in
            callback { promise.reject(failure) }
        })
        return promise
    }
}

// MARK: Bridging from Swift Concurrency Task

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Task {
    /// Converts a running `Task` into a `Promise` that mirrors the task’s
    /// eventual result.  Cancelling the promise cancels the task.
    @inlinable
    public var promise: Promise<Success, Failure> {
        let promise = Promise<Success, Failure>()
        let task = Task<Void, Never> {
            switch await self.result {
            case .success(let value): promise.resolve(value)
            case .failure(let error): promise.reject(error)
            }
        }
        promise.subscribe({ _ in task.cancel() }, { _ in task.cancel() })
        return promise
    }
}

