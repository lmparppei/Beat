//
//  File.swift
//  
//
//  Created by yuki on 2023/03/18.
//

import Foundation
import Promise
import lib0

final public class YPermanentUserData {
    public var yusers: YOpaqueMap // YMap<YMap<Any>> ...may be
    public var doc: YDocument
    public var clients: [Int: String]
    var dss: [String: YDeleteSet]

    public init(doc: YDocument, storeType: YOpaqueMap?) throws {
        self.yusers = storeType ?? doc.getOpaqueMap("users")
        self.doc = doc
        self.clients = [:]
        self.dss = [String: YDeleteSet]()
        
        func initUser(user: YOpaqueMap, userDescription: String) {
            let ds = user["ds"] as! YOpaqueArray // <Data>
            let ids = user["ids"] as! YOpaqueArray // <Int> ...may be
            func addClientId(clientid: Int) {
                self.clients[clientid] = userDescription
            }
            
            ds.observe{ event, _ in
                event.changes().added.forEach({ item in
                    item.content.values.forEach({ encodedDs in
                        if encodedDs is Data {
                            do {
                                let deleteSet = try YDeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(encodedDs as! Data)))
                                self.dss[userDescription] = YDeleteSet.mergeAll([
                                    self.dss[userDescription] ?? YDeleteSet(), deleteSet
                                ])
                            } catch {
                                print("Decode failed for user ('\(userDescription)').", error)
                            }
                        }
                    })
                })
            }
            
            self.dss[userDescription] = YDeleteSet.mergeAll(
                ds.compactMap{ data in
                    do {
                        return try YDeleteSet.decode(decoder: YDeleteSetDecoderV1(LZDecoder(data as! Data)))
                    } catch {
                        print("Decode failed for user ('\(userDescription)')", error)
                        return nil
                    }
                }
            )
            
            ids.observe{ event, _ in
                event.changes().added.forEach({ item in
                    item.content.values.forEach{
                        addClientId(clientid: $0 as! Int)
                    }
                })
            }
            
            ids.forEach{ i in
                addClientId(clientid: i as! Int)
            }
        }
        // observe users
        self.yusers.observe({ event, _ in
            (event as! YOpaqueMapEvent).keysChanged.forEach({ userDescription in
                initUser(user: self.yusers[userDescription!] as! YOpaqueMap, userDescription: userDescription!)
            })
        })
        // add intial data
        self.yusers.forEach{ key, value in
            initUser(user: value as! YOpaqueMap, userDescription: key)
        }
    }

    /**
     * @param {Doc} doc
     * @param {Int} clientid
     * @param {String} userDescription
     * @param {Object} conf
     * @param {function(Transaction, DeleteSet):Bool} [conf.filter]
     */
    public func setUserMapping(doc: YDocument, clientid: Int, userDescription: String, filter: @escaping (YTransaction, Any) -> Bool = {_, _ in true }) throws {
        let users = self.yusers
        var user = users[userDescription] as? YOpaqueMap
        
        if user == nil {
            user = YOpaqueMap()
            user!["ids"] = YOpaqueArray()
            user!["ds"] = YOpaqueArray()
            users[userDescription] = user!
        }
        
        (user!["ids"] as! YOpaqueArray).append(contentsOf: [clientid])
        
        users.observe{ _, _ in
            // may be for Dispatch
            Promise.wait(for: 0).tryPeek{
                let userOverwrite = users[userDescription] as? YOpaqueMap
                if userOverwrite != user {
                    user = userOverwrite
                    
                    self.clients.forEach({ clientid, _userDescription in
                        if userDescription == _userDescription {
                            (user!["ids"] as? YOpaqueArray)?.append(contentsOf: [clientid])
                        }
                    })
                    let encoder = YDeleteSetEncoderV1() as any YDeleteSetEncoder
                    let ds = self.dss[userDescription]
                    if ds != nil {
                        ds!.encode(into: encoder)
                        (user!["ds"] as! YOpaqueArray).append(contentsOf: [encoder.toData()])
                    }
                }
            }
            .catch{ print($0) }
        }
        
        doc.on(YDocument.On.afterTransaction) { transaction in
            Promise.wait(for: 0).tryPeek{
                let yds = user!["ds"] as! YOpaqueArray
                let ds = transaction.deleteSet
                if transaction.local && ds.clients.count > 0 && filter(transaction, ds) {
                    let encoder = YDeleteSetEncoderV1()
                    ds.encode(into: encoder)
                    yds.append(contentsOf: [encoder.toData()])
                }
            }.catch{ print($0) }
        }
    }

    public func getUserByClientId(_ clientid: Int) -> Any? {
        return self.clients[clientid]
    }

    public func getUserByDeletedId(_ id: YIdentifier) -> String? {
        for (userDescription, ds) in self.dss {
            if ds.isDeleted(id) {
                return userDescription
            }
        }
        return nil
    }
}

