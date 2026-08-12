//
//  File.swift
//  
//
//  Created by yuki on 2023/03/22.
//

import Foundation
import yswift

struct YTestEnvironment {
    let encodeStateAsUpdate: (YDocument, Data) throws -> YUpdate
    let mergeUpdates: ([YUpdate]) throws -> YUpdate
    let applyUpdate: (YDocument, YUpdate, Any?) throws -> Void
    let logUpdate: (YUpdate) -> Void
    let updateEventName: YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>
    let diffUpdate: (YUpdate, Data) throws -> YUpdate
        
    private static let v1 = YTestEnvironment(
        encodeStateAsUpdate: { try $0.encodeStateAsUpdate(encodedStateVector: $1) },
        mergeUpdates: { try YUpdate.merged($0) },
        applyUpdate: { try $0.applyUpdate($1, origin: $2) },
        logUpdate: { $0.log() },
        updateEventName: YDocument.On.update,
        diffUpdate: { try $0.diff(to: $1) }
    )
    
    private static let v2 = YTestEnvironment(
        encodeStateAsUpdate: { try $0.encodeStateAsUpdateV2(encodedStateVector: $1) },
        mergeUpdates: { try YUpdate.mergedV2($0) },
        applyUpdate: { try $0.applyUpdateV2($1, origin: $2) },
        logUpdate: { $0.log() },
        updateEventName: YDocument.On.updateV2,
        diffUpdate: { try $0.diffV2(to: $1) }
    )
    
    static var usingV2 = false
    static var currentEnvironment = YTestEnvironment.v1
    
    static func useV1() {
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
    
    static func useV2() {
        // As syncProtocol dosen't support v2
        self.usingV2 = false
        self.currentEnvironment = .v1
    }
}
