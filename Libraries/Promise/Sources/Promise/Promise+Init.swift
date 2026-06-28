//
//  Promise+Init.swift
//  
//
//  Created by yuki on 2021/10/28.
//

extension Promise {
    // MARK: Convenience initializers

    /// Creates a promise and immediately executes a handler that receives
    /// the promise’s `resolve` and `reject` functions.
    ///
    /// Use this variant for *non‑throwing* asynchronous work.
    ///
    /// - Parameter handler: A closure that performs the work and settles the
    ///   promise at an appropriate time.
    @inlinable
    public convenience init(@_implicitSelfCapture _ handler: (@escaping (Output) -> (), @escaping (Failure) -> ()) -> ()) {
        self.init()
        handler(self.resolve, self.reject)
    }
    
    /// Creates a promise whose handler may throw.
    ///
    /// If the handler throws, the promise is immediately rejected with the
    /// thrown error.
    @inlinable
    public convenience init(@_implicitSelfCapture _ handler: (@escaping (Output) -> (), @escaping (Failure) -> ()) throws -> ()) where Failure == Error {
        self.init()
        do { try handler(self.resolve, self.reject) } catch { self.reject(error) }
    }
    
    /// Wraps an *existing* promise, forwarding its eventual result.
    ///
    /// This is useful when you need an independent promise instance—for
    /// example, to apply additional operators—while maintaining strict
    /// once‑only semantics.
    @inlinable
    public convenience init(_ promise: Promise<Output, Failure>) {
        self.init()
        promise.subscribe(self.resolve, self.reject)
    }
    
    // MARK: Factory helpers

    /// Returns a promise already fulfilled with `output`.
    @inlinable
    public static func resolve(_ output: Output) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        promise.resolve(output)
        return promise
    }

    /// Returns a promise already fulfilled with `()`.
    @inlinable
    public static func resolve() -> Promise<Void, Failure> where Output == Void {
        let promise = Promise<Output, Failure>()
        promise.resolve(())
        return promise
    }
    
    /// Returns a promise already rejected with `failure`.
    @inlinable
    public static func reject(_ failure: Failure) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        promise.reject(failure)
        return promise
    }
    
    /// Immediately executes `output`, capturing either the returned value
    /// or thrown error.
    @inlinable
    public static func resolve(_ output: () throws -> Output) -> Promise<Output, Error> where Failure == Error {
        let promise = Promise<Output, Failure>()
        do {
            promise.resolve(try output())
        } catch {
            promise.reject(error)
        }
        return promise
    }
}

