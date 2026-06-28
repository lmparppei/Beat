//
//  Promise+Util.swift
//
//
//  Created by yuki on 2021/10/28.
//

extension Promise {
    // MARK: Utilities

    /// Returns the promise’s result if it has already settled, otherwise `nil`.
    @inlinable
    public var result: Result<Output, Failure>? {
        let state = self.state
        if case .fulfilled(let output) = state {
            return .success(output)
        }
        if case .rejected(let failure) = state {
            return .failure(failure)
        }
        return nil
    }
    
    /// A Boolean value indicating whether the promise is fulfilled or rejected.
    @inlinable
    public var isSettled: Bool {
        if case .pending = self.state { return false }
        return true
    }
}
