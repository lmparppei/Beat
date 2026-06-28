//
//  Promise+Combine.swift
//  Promise
//
//  Created by yuki on 2021/10/24.
//

#if canImport(Combine)
import Combine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Promise {
    
    /// Exposes the promise as a Combine `Publisher`.
    ///
    /// The returned publisher behaves like `Future`—publishing once then
    /// completing.  Multiple subscriptions do **not** multiply work; they
    /// simply observe the already‑running promise.
    @inlinable
    public func publisher() -> some Publisher<Output, Failure> {
        Future { handler in
            self.subscribe({ handler(.success($0)) }, { handler(.failure($0)) })
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher {
    
    /// Collects the **first** value from the publisher into a promise.
    ///
    /// If the publisher completes without emitting, the promise resolves with
    /// `nil`.  If it fails, the error is forwarded unchanged.
    @inlinable
    public func firstValue() -> Promise<Output?, Failure> {
        let promise = Promise<Output?, Failure>()

        var cancellable: AnyCancellable?
        
        cancellable = self.sink { completion in
            switch completion {
            case .finished: promise.resolve(nil)
            case .failure(let error): promise.reject(error)
            }
            cancellable?.cancel()
        } receiveValue: { value in
            promise.resolve(value)
            cancellable?.cancel()
        }
       
        return promise
    }
}
#endif
