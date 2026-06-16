//
//  File.swift
//  
//
//  Created by yuki on 2023/03/20.
//

import Foundation
@testable import yswift
import lib0

final public class YUpdateEnvironment {
    let mergeUpdates: (_ updates: [YUpdate]) throws -> YUpdate
    let encodeStateAsUpdate: (_ doc: YDocument, _ encodedTargetStateVector: Data?) throws -> YUpdate
    let applyUpdate: (_ ydoc: YDocument, _ update: YUpdate, _ origin: Any?) throws -> Void
    let logUpdate: (_ update: YUpdate) -> Void
    let parseUpdateMeta: (_ update: YUpdate) throws -> YUpdate.Meta
    let encodeStateVectorFromUpdate: (_ update: YUpdate) throws -> Data
    let encodeStateVector_Doc: (_ doc: YDocument) throws -> Data
    let encodeStateVector_SV: (_ doc: [Int: Int]) throws -> Data
    let updateEventName: YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>
    let description: String
    let diffUpdate: (_ update: YUpdate, _ sv: Data) throws -> YUpdate
    
    init(
        mergeUpdates: @escaping ([YUpdate]) throws -> YUpdate,
        encodeStateAsUpdate: @escaping (YDocument, Data?) throws -> YUpdate,
        applyUpdate: @escaping (YDocument, YUpdate, Any?) throws -> Void,
        logUpdate: @escaping (YUpdate) -> Void,
        parseUpdateMeta: @escaping (YUpdate) throws -> YUpdate.Meta,
        encodeStateVectorFromUpdate: @escaping (YUpdate) throws -> Data,
        encodeStateVector_Doc: @escaping (YDocument) throws -> Data,
        encodeStateVector_SV: @escaping ([Int : Int]) throws -> Data,
        updateEventName: LZObservableObject.EventName<(update: YUpdate, origin: Any?, YTransaction)>,
        description: String,
        diffUpdate: @escaping (YUpdate, Data) throws -> YUpdate
    ) {
        self.mergeUpdates = mergeUpdates
        self.encodeStateAsUpdate = encodeStateAsUpdate
        self.applyUpdate = applyUpdate
        self.logUpdate = logUpdate
        self.parseUpdateMeta = parseUpdateMeta
        self.encodeStateVectorFromUpdate = encodeStateVectorFromUpdate
        self.encodeStateVector_Doc = encodeStateVector_Doc
        self.encodeStateVector_SV = encodeStateVector_SV
        self.updateEventName = updateEventName
        self.description = description
        self.diffUpdate = diffUpdate
    }

    
    static let v1 = YUpdateEnvironment(
        mergeUpdates: { try YUpdate.merged($0) },
        encodeStateAsUpdate: { try $0.encodeStateAsUpdate(encodedStateVector: $1) },
        applyUpdate: { try $0.applyUpdate($1, origin: $2) },
        logUpdate: { $0.log() },
        parseUpdateMeta: { try $0.updateMeta() },
        encodeStateVectorFromUpdate: { try $0.encodeStateVectorFromUpdate() },
        encodeStateVector_Doc: { try $0.encodeStateVector() },
        encodeStateVector_SV: { try YDeleteSetEncoderV1().encodeStateVector(from: $0) },
        updateEventName: YDocument.On.update,
        description: "V1",
        diffUpdate: { try $0.diff(to: $1) }
    )

    static let v2 = YUpdateEnvironment(
        mergeUpdates: { try YUpdate.mergedV2($0) },
        encodeStateAsUpdate: { try $0.encodeStateAsUpdateV2(encodedStateVector: $1) },
        applyUpdate: { try $0.applyUpdateV2($1, origin: $2) },
        logUpdate: { $0.log() },
        parseUpdateMeta: { try $0.updateMetaV2() },
        encodeStateVectorFromUpdate: { try $0.encodeStateVectorFromUpdateV2() },
        encodeStateVector_Doc: { try $0.encodeStateVector() },
        encodeStateVector_SV: { try YDeleteSetEncoderV1().encodeStateVector(from: $0) },
        updateEventName: YDocument.On.updateV2,
        description: "V2",
        diffUpdate: { try $0.diffV2(to: $1) }
    )

    static let doc = YUpdateEnvironment(
        mergeUpdates: { updates in
            let ydoc = YDocument(YDocument.Options(gc: false))
            try updates.forEach{ try ydoc.applyUpdateV2($0) }
            return try ydoc.encodeStateAsUpdateV2()
        },
        encodeStateAsUpdate: { try $0.encodeStateAsUpdateV2(encodedStateVector: $1) },
        applyUpdate: { try $0.applyUpdateV2($1, origin: $2) },
        logUpdate: { $0.log() },
        parseUpdateMeta: { try $0.updateMetaV2() },
        encodeStateVectorFromUpdate: { try $0.encodeStateVectorFromUpdateV2() },
        encodeStateVector_Doc: { try $0.encodeStateVector() },
        encodeStateVector_SV: { try YDeleteSetEncoderV1().encodeStateVector(from: $0) },
        updateEventName: YDocument.On.updateV2,
        description: "Merge via Doc",
        diffUpdate: { update, sv in
            let ydoc = YDocument(YDocument.Options(gc: false))
            try ydoc.applyUpdateV2(update)
            return try ydoc.encodeStateAsUpdateV2(encodedStateVector: sv)
        }
    )

    static let encoders = [YUpdateEnvironment.v1, .v2, .doc]
    
    func docFromUpdates(_ docs: [YDocument]) throws -> YDocument {
        let updates = try docs.map{
            try self.encodeStateAsUpdate($0, nil)
        }
                
        let ydoc = YDocument()
        try self.applyUpdate(ydoc, self.mergeUpdates(updates), nil)
        return ydoc
    }
}
