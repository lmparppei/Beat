//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import Foundation
import XCTest
import lib0
@testable import yswift

class TestConnector: JSHashable {
    var connections = Set<TestDoc>()
    var onlineConnections = Set<TestDoc>()
    var randomGenerator: RandomGenerator
    
    init(_ randomGenerator: RandomGenerator) {
        self.connections = Set()
        self.onlineConnections = Set()
        self.randomGenerator = randomGenerator
    }
    
    @discardableResult
    func flushRandomMessage() throws -> Bool {
        let connections = self.onlineConnections.filter{ $0.receivingMessages.count > 0 }
        
        guard let document = connections.min(by: { $0.clientID < $1.clientID }) else {
            return false
        }
                    
        // to remove randomness
        let senderDocument = document.receivingMessages.keys.min(by: { $0.clientID < $1.clientID })!
        let messages = document.receivingMessages[senderDocument]!
                
        let data = messages.isEmpty ? nil : messages.value.removeFirst()
        
        if messages.count == 0 {
            document.receivingMessages.removeValue(forKey: senderDocument)
        }
        
        guard let receivedData = data else { return try self.flushRandomMessage() }
        
        let encoder = LZEncoder()
                
        try Sync.readSyncMessage(
            decoder: LZDecoder(receivedData),
            encoder: encoder, doc: document, origin: document.connector
        )
        
        if encoder.count > 0 { senderDocument._receive(encoder.data, remoteClient: document) }
        
        return true
    }

    @discardableResult
    func flushAllMessages() throws -> Bool {
        var didSomething = false
        while try self.flushRandomMessage() {
            didSomething = true
        }
        return didSomething
    }

    func reconnectAll() throws {
        try self.connections.forEach{ try $0.connect() }
    }

    func disconnectAll() {
        self.connections.forEach{ $0.disconnect() }
    }

    func syncAll() throws {
        try self.reconnectAll()
        try self.flushAllMessages()
    }

    @discardableResult
    func disconnectRandom() -> Bool {
        if self.onlineConnections.isEmpty { return false }
        
        randomGenerator.oneOf(self.onlineConnections.sorted(by: { $0.clientID < $1.clientID })).disconnect()
        
        return true
    }

    @discardableResult
    func reconnectRandom() throws -> Bool {
        var reconnectable = [TestDoc]()
        
        self.connections.sorted(by: { $0.clientID < $1.clientID }).forEach{
            if !self.onlineConnections.contains($0) {
                reconnectable.append($0)
            }
        }
        
        if reconnectable.isEmpty { return false }
        try self.randomGenerator.oneOf(reconnectable).connect()
        return true
    }
}
