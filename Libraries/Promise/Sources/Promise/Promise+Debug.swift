//
//  Promise+Debug.swift
//
//
//  Created by yuki on 2021/08/23.
//

@usableFromInline struct PrintTarget: TextOutputStream {
    @usableFromInline func write(_ string: String) { Swift.print(string) }
    
    @inlinable init() {}
}

extension Promise {
    // MARK: Assertions & logging

    /// Converts failures into a runtime trap during *DEBUG* builds.
    ///
    /// - Parameter prefix: Optional text prepended to the fatal error message.
    /// - Parameter file: The file where the assertion occurred.
    /// - Parameter line: The line number where the assertion occurred.
    @inlinable
    public func assertNoFailure(_ prefix: String = "", file: StaticString = #file, line: UInt = #line) -> Promise<Output, Never> {
        let promise = Promise<Output, Never>()
        self.subscribe(promise.resolve, { error in
           let prefix = prefix.isEmpty ? "" : prefix + ": "
           fatalError("\(prefix)\(error)", file: file, line: line)
        })
        return promise
    }
    
    /// Prints settlement events to `stdout` using `Swift.print`.
    ///
    /// - Parameter prefix: Prepended to every print for easy filtering.
    @inlinable
    public func print(_ prefix: String = "") -> Promise<Output, Failure> {
        var target = PrintTarget()
        return self.print(prefix, to: &target)
    }
    
    /// Prints settlement events to a custom `TextOutputStream`.
    @inlinable
    public func print<Target: TextOutputStream>(_ prefix: String = "", to target: inout Target) -> Promise<Output, Failure> {
        var target = target
        let prefix = prefix.isEmpty ? "" : "\(prefix): "
                
        self.subscribe({ output in
            target.write("\(prefix)receive output: (\(output))")
        }, { failure in
            target.write("\(prefix)receive failure: (\(failure))")
        })
        
        return self
    }
}

#if canImport(Darwin)
import Darwin

extension Promise {
    /// Triggers a debugger breakpoint when the supplied predicates return `true`.
    ///
    /// - Parameters:
    ///   - receiveOutput: Optional predicate executed on output.
    ///   - receiveFailure: Optional predicate executed on failure.
    /// - Returns: The original promise for further chaining.
    @inlinable
    public func breakpoint(@_implicitSelfCapture _ receiveOutput: ((Output) -> Bool)? = nil, @_implicitSelfCapture _ receiveFailure: ((Failure) -> Bool)? = nil) -> Promise<Output, Failure> {
        #if DEBUG
        self.subscribe({ output in
            if receiveOutput?(output) == true { raise(SIGTRAP) }
        }, { failure in
            if receiveFailure?(failure) == true { raise(SIGTRAP) }
        })
        #endif
        return self
    }

    /// Breaks into the debugger on *any* failure, after printing it.
    @inlinable
    public func breakpointOnError(_ prefix: String = "") -> Promise<Output, Failure> {
        #if DEBUG
        var target = PrintTarget()
        return self.breakpointOnError(prefix, to: &target)
        #else
        return self
        #endif
    }
    
    /// `breakpointOnError` variant that logs to a custom stream.
    @inlinable
    public func breakpointOnError<Target: TextOutputStream>(_ prefix: String = "", to target: inout Target) -> Promise<Output, Failure> {
        #if DEBUG
        var target = target
        let prefix = prefix.isEmpty ? "" : "\(prefix): "
        
        return self.breakpoint(nil, { failure in
            target.write("\(prefix)break failure: (\(failure))")
            return true
        })
        #else
        return self
        #endif
    }
}
#endif
