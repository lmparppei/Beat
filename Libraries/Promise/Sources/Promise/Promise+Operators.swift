//
//  Promise+Operators.swift
//  
//
//  Created by yuki on 2021/10/24.
//

extension Promise {
    // MARK: Transforming output

    /// Transforms the promise’s output synchronously.
    ///
    /// - Parameter transform: A mapping closure executed when the promise
    ///   fulfills.
    /// - Returns: A new promise whose output is the transformed value.
    @inlinable
    public func map<T>(@_implicitSelfCapture _ transform: @escaping (Output) -> T) -> Promise<T, Failure> {
        let promise = Promise<T, Failure>()
        self.subscribe({ promise.resolve(transform($0)) }, promise.reject)
        return promise
    }
    
    /// Chains another promise using the current output.
    ///
    /// - Parameter transform: A closure that returns a *new* promise.
    /// - Returns: A promise that mirrors the child promise’s result.
    @inlinable
    public func flatMap<T>(@_implicitSelfCapture _ transform: @escaping (Output) -> Promise<T, Failure>) -> Promise<T, Failure> {
        let promise = Promise<T, Failure>()
        self.subscribe({ transform($0).subscribe(promise.resolve, promise.reject) }, promise.reject)
        return promise
    }
    
    /// A `flatMap` variant where the transform reports via callbacks.
    @inlinable
    public func flatMap<T>(@_implicitSelfCapture _ transform: @escaping (Output, @escaping (T) -> (), @escaping (Failure) -> ()) -> ()) -> Promise<T, Failure> {
        let promise = Promise<T, Failure>()
        self.subscribe({ transform($0, promise.resolve, promise.reject) }, promise.reject)
        return promise
    }
    
    // MARK: Throwing transforms

    /// `map` that can throw, automatically converting thrown errors.
    @inlinable
    public func tryMap<T>(@_implicitSelfCapture _ transform: @escaping (Output) throws -> T) -> Promise<T, Error> {
        let promise = Promise<T, Error>()
        self.subscribe({ do { try promise.resolve(transform($0)) } catch { promise.reject(error) } }, promise.reject)
        return promise
    }
    
    /// `flatMap` that can throw, forwarding errors automatically.
    @inlinable
    public func tryFlatMap<T>(@_implicitSelfCapture _ transform: @escaping (Output) throws -> Promise<T, Error>) -> Promise<T, Error> {
        let promise = Promise<T, Error>()
        self.subscribe({
            do { try transform($0).subscribe(promise.resolve, promise.reject) } catch { promise.reject(error) }
        }, promise.reject)
        return promise
    }
    
    /// Callback‑style `flatMap` that can throw.
    @inlinable
    public func tryFlatMap<T>(@_implicitSelfCapture _ transform: @escaping (Output, @escaping (T) -> (), @escaping (Failure) -> ()) throws -> ()) -> Promise<T, Error> {
        let promise = Promise<T, Error>()
        self.subscribe({
            do { try transform($0, promise.resolve, promise.reject) } catch { promise.reject(error) }
        }, promise.reject)
        return promise
    }
    
    // MARK: Error–centric operators

    /// Converts the promise’s `Failure` to another error type.
    @inlinable
    public func mapError<T>(@_implicitSelfCapture _ transform: @escaping (Failure) -> T) -> Promise<Output, T> {
        let promise = Promise<Output, T>()
        self.subscribe(promise.resolve, { promise.reject(transform($0)) })
        return promise
    }
    
    /// Replaces any failure with a fallback output, producing an error‑free
    /// promise.
    @inlinable
    public func replaceError(@_implicitSelfCapture _ transform: @escaping (Failure) -> Output) -> Promise<Output, Never> {
        let promise = Promise<Output, Never>()
        self.subscribe(promise.resolve, { promise.resolve(transform($0)) })
        return promise
    }
    
    /// Replaces any failure with a constant fallback output.
    @inlinable
    public func replaceError(@_implicitSelfCapture with value: @autoclosure @escaping () -> Output) -> Promise<Output, Never> {
        let promise = Promise<Output, Never>()
        self.subscribe(promise.resolve, {_ in promise.resolve(value()) })
        return promise
    }
    
    /// Replaces failure with `nil`, retaining `Optional` output semantics.
    @inlinable
    public func replaceErrorWithNil<T>() -> Promise<Output, Never> where Output == Optional<T> {
        let promise = Promise<Output, Never>()
        self.subscribe(promise.resolve, {_ in promise.resolve(nil) })
        return promise
    }
    
    /// Promotes a non‑optional `Output` to an optional and inserts `nil` on
    /// failure.
    @inlinable
    public func replaceErrorWithNil() -> Promise<Output?, Never> {
        let promise = Promise<Output?, Never>()
        self.subscribe(promise.resolve, {_ in promise.resolve(nil) })
        return promise
    }
        
    /// Like ``replaceError(_:)`` but allows the transformer to throw.
    @inlinable
    public func tryReplaceError(@_implicitSelfCapture _ transform: @escaping (Failure) throws -> Output) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe(promise.resolve, {
            do { try promise.resolve(transform($0)) } catch { promise.reject(error) }
        })
        return promise
    }
    
    /// Erases the `Failure` type to `Swift.Error`.
    @inlinable
    public func eraseToError() -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe(promise.resolve, promise.reject)
        return promise
    }
    
    /// Discards the output, mapping any fulfillment to `Void`.
    @inlinable
    public func eraseToVoid() -> Promise<Void, Failure> {
        let promise = Promise<Void, Failure>()
        self.subscribe({_ in promise.resolve(()) }, promise.reject)
        return promise
    }
    
    /// Wraps the result in `Swift.Result`.
    @inlinable
    public func packToResult() -> Promise<Result<Output, Failure>, Never> {
        let promise = Promise<Result<Output, Failure>, Never>()
        self.subscribe({ promise.resolve(.success($0)) }, { promise.resolve(.failure($0)) })
        return promise
    }
    
    /// Extracts the payload from a `Result`, forwarding errors.
    @inlinable
    public func unpackResult<O>() -> Promise<O, Failure> where Output == Result<O, Failure> {
        let promise = Promise<O, Failure>()
        self.subscribe({
            switch $0 {
            case .success(let output): promise.resolve(output)
            case .failure(let failure): promise.reject(failure)
            }
        }, promise.reject)
        return promise
    }
    
    /// Like ``unpackResult()`` but when the *parent* promise cannot fail.
    @inlinable
    public func unpackResult<O, F>() -> Promise<O, F> where Output == Result<O, F>, Failure == Never {
        let promise = Promise<O, F>()
        self.subscribe({
            switch $0 {
            case .success(let output): promise.resolve(output)
            case .failure(let failure): promise.reject(failure)
            }
        }, {_ in})
        return promise
    }
    
    // MARK: Side‑effects

    /// Executes `receiveOutput` when the promise fulfills without changing the
    /// chain.
    @inlinable
    public func peek(@_implicitSelfCapture _ receiveOutput: @escaping (Output) -> ()) -> Promise<Output, Failure> {
        self.subscribe(receiveOutput, {_ in})
        return self
    }
    
    /// Executes `receiveFailure` when the promise rejects.
    @inlinable
    public func peekError(@_implicitSelfCapture _ receiveFailure: @escaping (Failure) -> ()) -> Promise<Output, Failure> {
        self.subscribe({_ in}, receiveFailure)
        return self
    }
    
    /// Throws inside `receiveOutput` are forwarded as rejections.
    @inlinable
    public func tryPeek(@_implicitSelfCapture _ receiveOutput: @escaping (Output) throws -> ()) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe({ output in
            do { try receiveOutput(output); promise.resolve(output) } catch { promise.reject(error) }
        }, promise.reject)
        return promise
    }
    
    /// Runs `transform` and waits for its promise before forwarding the
    /// *original* output.
    @inlinable
    public func flatPeek<T>(@_implicitSelfCapture _ transform: @escaping (Output) -> Promise<T, Failure>) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        self.subscribe({ output in transform(output).subscribe({_ in promise.resolve(output) }, promise.reject) }, promise.reject)
        return promise
    }

    /// `flatPeek` variant that can throw.
    @inlinable
    public func tryFlatPeek<T>(@_implicitSelfCapture _ transform: @escaping (Output) throws -> Promise<T, Failure>) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe({ output in
            do { try transform(output).subscribe({_ in promise.resolve(output) }, promise.reject) } catch { promise.reject(error) }
        }, promise.reject)
        return promise
    }
    
    // MARK: Catch / finally

    /// Catches any failure, executing `receiveFailure` and producing a
    /// `Void`‑output promise.
    @discardableResult
    @inlinable
    public func `catch`(@_implicitSelfCapture _ receiveFailure: @escaping (Failure) -> ()) -> Promise<Void, Never> {
        let promise = Promise<Void, Never>()
        self.subscribe({ _ in promise.resolve(()) }, { receiveFailure($0); promise.resolve(()) })
        return promise
    }

    /// Catches *specific* error types, passing through unhandled errors.
    @inlinable
    public func `catch`<ErrorType: Error>(_ errorType: ErrorType.Type, @_implicitSelfCapture _ receiveFailure: @escaping (ErrorType) -> ()) -> Promise<Output, Failure> {
        let promise = Promise<Output, Failure>()
        self.subscribe(promise.resolve, { failure in
            if let error = failure as? ErrorType { receiveFailure(error) }
            promise.reject(failure)
        })
        return promise
    }
    
    /// `catch` that can throw, forwarding secondary errors.
    @inlinable
    public func tryCatch(@_implicitSelfCapture _ receiveFailure: @escaping (Failure) throws -> ()) -> Promise<Void, Error> {
        let promise = Promise<Void, Error>()
        self.subscribe({_ in promise.resolve(()) }, { failure in
            do { try receiveFailure(failure); promise.resolve(()) } catch { promise.reject(error) }
        })
        return promise
    }
    
    /// Typed `tryCatch`.
    @inlinable
    public func tryCatch<ErrorType: Error>(_ errorType: ErrorType.Type, @_implicitSelfCapture _ receiveFailure: @escaping (ErrorType) throws -> ()) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe(promise.resolve, { failure in
            if let error = failure as? ErrorType {
                do { try receiveFailure(error) } catch { promise.reject(error) }
            }
            promise.reject(failure)
        })
        return promise
    }
    
    /// Converts an optional `Error` output into an error channel.
    @inlinable
    public func integrateError() -> Promise<Void, Error> where Output == Optional<Error> {
        let promise = Promise<Void, Error>()
        self.subscribe({ if let error = $0 { promise.reject(error) } else { promise.resolve(()) } }, promise.reject)
        return promise
    }
    
    /// Runs `receive` regardless of success or failure.
    @discardableResult
    @inlinable
    public func finally(@_implicitSelfCapture _ receive: @escaping () -> ()) -> Promise<Output, Failure> {
        self.subscribe({_ in receive() }, {_ in receive() })
        return self
    }
    
    /// `finally` that can throw, promoting errors to the returned promise.
    @inlinable
    public func tryFinally(@_implicitSelfCapture _ receive: @escaping () throws -> ()) -> Promise<Output, Error> {
        let promise = Promise<Output, Error>()
        self.subscribe({ output in
            do { try receive(); promise.resolve(output) } catch { promise.reject(error) }
        }, { failure in
            do { try receive(); promise.reject(failure) } catch { promise.reject(error) }
        })
        return promise
    }
    
    // MARK: Sinks

    /// Consumes both output and failure, terminating the chain.
    @inlinable
    public func sink(@_implicitSelfCapture _ receiveOutput: @escaping (Output) -> (), @_implicitSelfCapture _ receiveFailure: @escaping (Failure) -> ()) {
        self.subscribe(receiveOutput, receiveFailure)
    }
    
    /// Consumes output for promises that cannot fail.
    @inlinable
    public func sink(@_implicitSelfCapture _ receiveOutput: @escaping (Output) -> ()) where Failure == Never {
        self.subscribe(receiveOutput, {_ in })
    }
    
    // MARK: Manual resolution helpers

    /// Fulfills a `Void` promise with `()`.
    @inlinable
    public func resolve() where Output == Void {
        self.resolve(())
    }
    
    /// Fulfills a promise whose `Failure == Never` using the closure’s value.
    @inlinable
    public func resolve(_ output: () -> Output) where Failure == Never {
        self.resolve(output())
    }
    
    /// Executes `output`, resolving or rejecting depending on whether it throws.
    @inlinable
    public func resolve(_ output: () throws -> Output) where Failure == Error {
        do {
            self.resolve(try output())
        } catch {
            self.reject(error)
        }
    }
}
