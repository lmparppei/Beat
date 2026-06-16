//
//  CombineLatestCollection.swift
//  CoreUtil
//
//  Created by yuki on 2020/06/13.
//  Copyright © 2020 yuki. All rights reserved.
//

import Foundation
import Combine

extension Collection where Element: Publisher {
    /// emptyの時に空配列を流す
    @inlinable public var combineLatestHandleEmpty: Publishers.CombineLatestCollectionHandleEmpty<Self> {
        Publishers.CombineLatestCollectionHandleEmpty(upstreams: self)
    }
}

extension Collection where Element: Publisher {
    /// Collection内の全てをcombineLatestする。
    /// Completeした後に出力された値を使ってはいけない
    @inlinable public var combineLatest: Publishers.CombineLatestCollection<Self> {
        Publishers.CombineLatestCollection(upstreams: self)
    }
}

extension Publishers {
    public struct CombineLatestCollectionHandleEmpty<Upstreams: Collection>: Publisher where Upstreams.Element: Combine.Publisher {
        public typealias Output = UnsafeMutableBufferPointer<Upstreams.Element.Output>
        public typealias Failure = Upstreams.Element.Failure
        public typealias Inner = CombineLatestCollection<Upstreams>.Inner
        
        public enum Publisher {
            case publishers(Upstreams)
            case empty(Just<Output>)
        }
        
        public let publisher: Publisher

        @inlinable public init(upstreams: Upstreams) {
            if upstreams.isEmpty {
                let storage = Output.allocate(capacity: 0)
                _ = storage.initialize(from: [])
                self.publisher = .empty(Just(storage))
            } else {
                self.publisher = .publishers(upstreams)
            }
        }

        @inlinable public func receive<Downstream: Subscriber>(subscriber downstream: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Self.Failure
        {
            switch self.publisher {
            case .empty(let just):
                just.convertToFailure().receive(subscriber: downstream)
            case .publishers(let publishers):
                let inner = Inner<Downstream>(downstream: downstream, upstreamCount: publishers.count)
                publishers.enumerated().forEach{ i, upstream in upstream.map{ (i, $0) }.subscribe(inner) }
            }
        }
    }
}

extension Publishers {
    public struct CombineLatestCollection<Upstreams: Collection>: Publisher where Upstreams.Element: Combine.Publisher {
        public typealias Output = UnsafeMutableBufferPointer<Upstreams.Element.Output>
        public typealias Failure = Upstreams.Element.Failure

        public let upstreams: Upstreams
        
        @inlinable public init(upstreams: Upstreams) { self.upstreams = upstreams }
        
        @inlinable public func receive<Downstream: Subscriber>(subscriber downstream: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Self.Failure
        {
            let inner = Inner<Downstream>(downstream: downstream, upstreamCount: upstreams.count)
            self.upstreams.enumerated().forEach{ i, upstream in upstream.map{ (i, $0) }.subscribe(inner) }
        }
    }
}

extension Publishers.CombineLatestCollection {
    public final class Inner<Downstream: Combine.Subscriber>: Combine.Subscriber
        where Downstream.Input == UnsafeMutableBufferPointer<Upstreams.Element.Output>
    {
        public typealias Input = (index: Int, value: Upstreams.Element.Output)
        public typealias Failure = Downstream.Failure
        
        @usableFromInline let downstream: Downstream
        @usableFromInline let upstreamCount: Int
        @usableFromInline let subscription = Subscription()
        
        /// 値を受けとったかどうかを保存するFlag
        /// 毎回non nil判定を行うのは重いので、flag管理をしている。全ての値を受け取った後に`deallocate`される
        @usableFromInline let receivedFlags: UnsafeMutableBufferPointer<Bool>
        /// 全ての値を受け取るまでのstorage
        /// 毎回unwrapをするのは重いので全ての値を受け取るまでは`prebuildStorage`、全ての値を受け取った後は`valueStorage`で管理している。
        @usableFromInline let prebuildStorage: UnsafeMutableBufferPointer<Upstreams.Element.Output?>
        /// 全ての値を受け取った後のstorage
        @usableFromInline let valueStorage: UnsafeMutableBufferPointer<Upstreams.Element.Output>
        
        /// すでに全ての値を受け取ったかどうか
        @usableFromInline var receivedAllValues = false
        /// 完了しているかどうか（`failure`を受け取った or 全てのupstreamがfinishedした）
        @usableFromInline var isCompleted = false
        /// 受け取ったfinishedのCount
        @usableFromInline var finishedCount: Int = 0
                
        @inlinable init(downstream: Downstream, upstreamCount: Int) {
            self.downstream = downstream
            self.upstreamCount = upstreamCount
            
            self.prebuildStorage = .allocate(capacity: upstreamCount)
            self.prebuildStorage.initialize(repeating: nil)
            
            self.valueStorage = .allocate(capacity: upstreamCount)
            
            self.receivedFlags = .allocate(capacity: upstreamCount)
            self.receivedFlags.initialize(repeating: false)
        }
        
        @inlinable public func receive(subscription: Combine.Subscription) {
            self.subscription.subscriptions.append(subscription)
            guard self.subscription.subscriptions.count == upstreamCount else { return }
            self.downstream.receive(subscription: self.subscription)
        }
        
        @inlinable public func receive(_ input: (index: Int, value: Upstreams.Element.Output)) -> Subscribers.Demand {
            if receivedAllValues {
                self.valueStorage[input.index] = input.value
                return self.downstream.receive(self.valueStorage)
            } else {
                self.prebuildStorage[input.index] = input.value
                self.receivedFlags[input.index] = true
            }
            
            // on complete
            if self.receivedFlags.allSatisfy({ $0 }) {
                _ = self.valueStorage.initialize(from: self.prebuildStorage.lazy.map{ $0! })
                
                self.receivedAllValues = true
                self.prebuildStorage.deallocate()
                self.receivedFlags.deallocate()
                return self.downstream.receive(self.valueStorage)
            }
            
            return .none
        }
        
        @inlinable public func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            guard !isCompleted else { return }
            
            switch completion {
            case .failure(let error):
                self.isCompleted = true
                self.valueStorage.deallocate()
                self.downstream.receive(completion: .failure(error))
            case .finished:
                self.finishedCount += 1
                if finishedCount == upstreamCount {
                    self.isCompleted = true
                    self.valueStorage.deallocate()
                    self.downstream.receive(completion: .finished)
                }
            }
        }
    }
    
    final public class Subscription: Combine.Subscription {
        @usableFromInline var subscriptions = [Combine.Subscription]()
        
        public func request(_ demand: Subscribers.Demand) {
            for subscription in subscriptions {
                subscription.request(demand)
            }
        }
        
        public func cancel() {
            for subscription in subscriptions {
                subscription.cancel()
            }
        }
    }
}

extension Publisher {
    public func convertToFailure<T: Error>() -> Publishers.MapError<Self, T> {
        self.mapError{_ in fatalError() }
    }
}
