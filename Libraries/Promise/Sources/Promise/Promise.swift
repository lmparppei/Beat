//
//  Promise.swift
//
//
//  Created by yuki on 2020/10/11.
//

/// A container that represents the eventual result of an asynchronous operation.
///
/// A `Promise` transitions through *exactly one* of three mutually‑exclusive
/// states over its lifetime:
///
/// * ``Promise/State/pending`` – The default state; no value is available yet.
/// * ``Promise/State/fulfilled(_:)`` – The asynchronous work succeeded and
///   produced an associated `Output`.
/// * ``Promise/State/rejected(_:)`` – The work failed with an associated
///   `Failure` error.
///
/// You create a promise, hand it out, and later *settle* it by calling either
/// ``resolve(_:)-(Output)->()`` or ``reject(_:)-(Failure)->()``.  Each attached subscriber receives the
/// result **exactly once**, even if it attaches *after* settlement.
///
/// ```swift
/// func makeImage() -> Promise<UIImage, Error> {
///     Promise { resolve, reject in
///         URLSession.shared.dataTask(with: url) { data, _, error in
///             if let data, let image = UIImage(data: data) {
///                 resolve(image)
///             } else {
///                 reject(error ?? URLError(.badServerResponse))
///             }
///         }.resume()
///     }
/// }
/// ```
///
/// ### Thread safety
/// All state transitions are serialized using an internal lock,
/// so `Promise` is safe to resolve or reject from any
/// thread. Callbacks execute synchronously on the thread that settles the
/// promise unless you explicitly schedule them elsewhere.
///
/// ### Memory semantics
/// Promises retain their subscribers until settlement, then release them
/// immediately. In *DEBUG* builds an assertion fires if a still‑pending
/// promise is leaked, helping you track down forgotten completions.
///
/// - Note: `Promise` purposefully avoids *any* built‑in scheduling policy so it
///   can be used equally well on the main queue, background queues, or
///   priority inheritance contexts.
public final class Promise<Output, Failure: Error> {
    /// The internal state of a ``Promise``.
    public enum State {
        /// The promise has not been settled yet.
        case pending
        /// The promise was resolved with the given `Output`.
        case fulfilled(Output)
        /// The promise was rejected with the given `Failure`.
        case rejected(Failure)
    }
    
    /// A paired collection of callbacks representing a single subscriber.
    @usableFromInline typealias Subscriber = (resolve: (Output) -> (), reject: (Failure) -> ())
    
    /// The current ``State`` of the promise.
    ///
    /// Access is O(1) and thread‑safe.
    @inlinable public var state: State {
        self._lock.lock()
        defer { self._lock.unlock() }
        return self._state
    }
    
    // MARK: Internal storage

    @usableFromInline var _state = State.pending
    @usableFromInline var _subscribers = [Subscriber]()
    @usableFromInline var _lock = RecursiveLock()

    /// Creates an *unsettled* promise.
    ///
    /// You are responsible for calling either ``resolve(_:)-(Output)->()`` or ``reject(_:)-(Failure)->()``
    /// at some later point.
    @inlinable public init() {}
    
    #if DEBUG
    /// In *DEBUG* builds, asserts if the promise is leaked without being settled.
    @inlinable deinit {
        if case .pending = self._state, !self._subscribers.isEmpty {
            assertionFailure("Unresolved release of Promise.")
        }
    }
    #endif
}

// MARK: - Settlement

extension Promise {
    /// Satisfies the promise with the supplied output *unless* it has already
    /// been settled.
    ///
    /// - Parameter output: The value that fulfills the promise.
    @inlinable
    public func resolve(_ output: Output) {
        self._lock.lock()
        defer { self._lock.unlock() }
        
        guard case .pending = self._state else { return }
        
        self._state = .fulfilled(output)
        
        for subscriber in self._subscribers {
            subscriber.resolve(output)
        }
        
        self._subscribers.removeAll()
    }
    
    /// Fails the promise with the supplied error *unless* it has already
    /// been settled.
    ///
    /// - Parameter failure: The error that rejects the promise.
    @inlinable
    public func reject(_ failure: Failure) {
        self._lock.lock()
        defer { self._lock.unlock() }
        
        guard case .pending = self._state else { return }
        
        self._state = .rejected(failure)
        
        for subscriber in self._subscribers {
            subscriber.reject(failure)
        }
        
        self._subscribers.removeAll()
    }

    /// Registers callbacks to be invoked when the promise settles.
    ///
    /// If the promise is already fulfilled or rejected, the corresponding
    /// callback runs immediately on the current thread.
    ///
    /// - Parameters:
    ///   - resolve: Invoked with the promise’s output on fulfillment.
    ///   - reject:  Invoked with the promise’s error on rejection.
    @inlinable
    func subscribe(_ resolve: @escaping (Output) -> (), _ reject: @escaping (Failure) -> ()) {
        self._lock.lock()
        defer { self._lock.unlock() }
        
        switch self._state {
        case .pending: self._subscribers.append((resolve: resolve, reject: reject))
        case .fulfilled(let output): resolve(output)
        case .rejected(let failure): reject(failure)
        }
    }
}

extension Promise: CustomStringConvertible {
    /// A textual description suitable for debugging.
    @inlinable public var description: String {
        "Promise<\(Output.self), \(Failure.self)>(\(self._state))"
    }
}
