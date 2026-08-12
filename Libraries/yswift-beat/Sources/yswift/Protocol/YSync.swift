import Foundation
import lib0

public enum YSync {
    
    public enum Error: Swift.Error {
        case unknownMessageType
    }
    
    public enum MessageType: UInt {
        case step1 = 0
        case step2 = 1
        case update = 2
    }
    
    public static func writeSyncStep1(encoder: LZEncoder, doc: YDocument) throws {
        encoder.writeUInt(MessageType.step1.rawValue)
        let sv = try doc.encodeStateVector()
        encoder.writeData(sv)
    }

    
    public static func writeSyncStep2(encoder: LZEncoder, doc: YDocument, encodedStateVector: Data?) throws {
        encoder.writeUInt(MessageType.step2.rawValue)
        encoder.writeData(try doc.encodeStateAsUpdate(encodedStateVector: encodedStateVector).data)
    }
    
    public static func readSyncStep1(decoder: LZDecoder, encoder: LZEncoder, doc: YDocument) throws {
        try writeSyncStep2(encoder: encoder, doc: doc, encodedStateVector: try decoder.readData())
    }
    
    public static func readSyncStep2(decoder: LZDecoder, doc: YDocument, transactionOrigin: Any? = nil) {
        do {
            let data = try decoder.readData()
            try doc.applyUpdate(YUpdate(data, version: .v1), origin: transactionOrigin)
        } catch {
            print("Caught error while handling a Yjs update")
        }
    }

    public static func writeUpdate(encoder: LZEncoder, update: YUpdate) {
        encoder.writeUInt(MessageType.update.rawValue)
        encoder.writeData(update.data)
    }
    
    public static func readUpdate(decoder: LZDecoder, doc: YDocument, transactionOrigin: Any? = nil) {
        readSyncStep2(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
    }

    public static func readSyncMessage(decoder: LZDecoder, encoder: LZEncoder, doc: YDocument, transactionOrigin: Any? = nil) throws -> MessageType {
        guard let messageType = MessageType(rawValue: try decoder.readUInt()) else {
            throw YSync.Error.unknownMessageType
        }
        
        switch messageType {
        case .step1:
            try self.readSyncStep1(decoder: decoder, encoder: encoder, doc: doc)
        case .step2:
            self.readSyncStep2(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
        case .update:
            self.readUpdate(decoder: decoder, doc: doc, transactionOrigin: transactionOrigin)
        }
        
        return messageType
    }
}

