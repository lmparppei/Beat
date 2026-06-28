//
//  Promise+URLSession.swift
//  Promise
//
//  Created by yuki on 2021/08/07.
//

#if canImport(Foundation)
import Foundation

extension URLSession {
    
    /// Convenience wrapper for `data(for:)` that returns only the raw data.
    @inlinable
    public func data(for url: URL) -> Promise<Data, Error> {
        self.fetch(url).map { $0.1 }
    }
    
    /// Same as ``data(for:)`` but for `URLRequest`.
    @inlinable
    public func data(for request: URLRequest) -> Promise<Data, Error> {
        self.fetch(request).map { $0.1 }
    }
    
    /// Performs a GET against `url`, yielding the `URLResponse` and `Data`.
    @inlinable
    public func fetch(_ url: URL) -> Promise<(URLResponse, Data), Error> {
        self.fetch(URLRequest(url: url))
    }
    
    /// General‑purpose wrapper around `URLSession.dataTask(with:)`.
    ///
    /// The promise is resolved with `(response, data)` or rejected with:
    /// * the underlying `URLSession` error;
    /// * a synthesized `NSError` when no data/error is produced.
    @inlinable
    public func fetch(_ request: URLRequest) -> Promise<(URLResponse, Data), Error> {
        let promise = Promise<(URLResponse, Data), Error>()
        
        self.dataTask(with: request) { data, responce, error in
            if let error = error {
                promise.reject(error)
            } else if let data = data, let responce = responce {
                promise.resolve((responce, data))
            } else {
                promise.reject(NSError(domain: "Promise", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Data task received no data and no error."
                ]))
            }
        }
        .resume()
        
        return promise
    }
}

extension Data {
    /// Asynchronously loads the contents of `url` into memory.
    @inlinable
    public static func async(contentsOf url: URL) -> Promise<Data, Error> {
        URLSession.shared.data(for: url)
    }
}

extension String {
    /// Asynchronously loads a remote string with the specified encoding.
    @inlinable
    public static func async(contentsOf url: URL, encoding: Encoding) -> Promise<String, Error> {
        Promise.tryDispatch { try String(contentsOf: url, encoding: encoding) }
    }
}

#endif
