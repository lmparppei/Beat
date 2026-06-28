//
//  Lock.swift
//  Promise
//
//  Created by yuki on 2023/06/28.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Bionic)
import Bionic
#elseif canImport(WASILibc)
import WASILibc
#if canImport(wasi_pthread)
import wasi_pthread
#endif
#else
#error("Unsupported platform")
#endif

@usableFromInline final class Lock: @unchecked Sendable {
    @usableFromInline @inline(__always) nonisolated(unsafe) static let attr: UnsafePointer<pthread_mutexattr_t> = {
        let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        _HANDLE_PTHREAD_CALL(pthread_mutexattr_init(attr), "pthread_mutexattr_init")
        #if DEBUG
        _HANDLE_PTHREAD_CALL(pthread_mutexattr_settype(attr, PTHREAD_MUTEX_ERRORCHECK), "pthread_mutexattr_settype")
        #endif
        return UnsafePointer(attr)
    }()

    @usableFromInline let mutex: UnsafeMutablePointer<pthread_mutex_t>
    
    @inlinable @inline(__always)
    init() {
        self.mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        self.mutex.assertValidAlignment()
        #if DEBUG
        _HANDLE_PTHREAD_CALL(pthread_mutex_init(mutex, Lock.attr), "pthread_mutex_init")
        #else
        _HANDLE_PTHREAD_CALL(pthread_mutex_init(mutex, nil), "pthread_mutex_init")
        #endif
    }
    
    @inlinable @inline(__always)
    deinit {
        _HANDLE_PTHREAD_CALL(pthread_mutex_destroy(mutex), "pthread_mutex_destroy")
    }
    
    @inlinable @inline(__always)
    func lock() {
        _HANDLE_PTHREAD_CALL(pthread_mutex_lock(mutex), "pthread_mutex_lock")
    }
    
    @inlinable @inline(__always)
    func unlock() {
        _HANDLE_PTHREAD_CALL(pthread_mutex_unlock(mutex), "pthread_mutex_unlock")
    }
}

@usableFromInline final class RecursiveLock: @unchecked Sendable {
    @usableFromInline @inline(__always) nonisolated(unsafe) static let attr = {
        let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        _HANDLE_PTHREAD_CALL(pthread_mutexattr_init(attr), "pthread_mutexattr_init")
        _HANDLE_PTHREAD_CALL(pthread_mutexattr_settype(attr, PTHREAD_MUTEX_RECURSIVE), "pthread_mutexattr_settype")
        #if DEBUG
        _HANDLE_PTHREAD_CALL(pthread_mutexattr_settype(attr, PTHREAD_MUTEX_ERRORCHECK), "pthread_mutexattr_settype")
        #endif
        return UnsafePointer(attr)
    }()
    
    @usableFromInline let mutex: UnsafeMutablePointer<pthread_mutex_t>
    
    @inlinable @inline(__always)
    init() {
        self.mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        self.mutex.assertValidAlignment()
        _HANDLE_PTHREAD_CALL(pthread_mutex_init(mutex, RecursiveLock.attr), "pthread_mutex_init")
    }
    
    @inlinable @inline(__always)
    deinit {
        _HANDLE_PTHREAD_CALL(pthread_mutex_destroy(mutex), "pthread_mutex_destroy")
    }
    
    @inlinable @inline(__always)
    func lock() {
        _HANDLE_PTHREAD_CALL(pthread_mutex_lock(mutex), "pthread_mutex_lock")
    }
    
    @inlinable @inline(__always)
    func unlock() {
        _HANDLE_PTHREAD_CALL(pthread_mutex_unlock(mutex), "pthread_mutex_unlock")
    }
}

@inlinable @_transparent
func _HANDLE_PTHREAD_CALL(_ res: Int32, _ funcname: @autoclosure () -> StaticString) {
    if res != 0 {
        fatalError("\(funcname()) failed: \(String(validatingCString: strerror(res)) ?? "Unkown Error")")
    }
}

extension UnsafeMutablePointer {
    @inlinable @_transparent
    func assertValidAlignment() {
        assert(UInt(bitPattern: self) % UInt(MemoryLayout<Pointee>.alignment) == 0)
    }
}
