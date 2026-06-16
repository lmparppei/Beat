//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    
    func _copyWithSmartCopy(map: YObject, value: Any?, key: String, context: YObject.SmartCopyContext) {
        if key == YObject.objectIDKey { return }
        
        assert(key.starts(with: "&"))
        
        if let id = value as? YObjectID.RawValue {
            context.writers[id] = {
                map._setValue($0, for: key)
            }
        } else if let value = value as? [YObjectID.RawValue] {
            var takeValues = [YObjectID.RawValue]()
            for id in value {
                context.writers[id] = { newID in // newID
                    takeValues.append(newID)
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        } else if let value = value as? [String: YObjectID.RawValue] {
            var takeValues = [String: YObjectID.RawValue]()
            for (mkey, id) in value {
                context.writers[id] = { newID in // newID
                    takeValues[mkey] = newID
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        } else if let value = value as? YOpaqueArray, value.allSatisfy({ $0 is YObjectID.RawValue }) {
            var takeValues = [YObjectID.RawValue]()
            for id in value {
                context.writers[id as! YObjectID.RawValue] = { newID in // newID
                    takeValues.append(newID)
                    if takeValues.count == value.count { map._setValue(YOpaqueArray(takeValues), for: key) }
                }
            }
        } else if let value = value as? YOpaqueMap, value.values().allSatisfy({ $0 is YObjectID.RawValue }) {
            var takeValues = [String: YObjectID.RawValue]()
            for (mkey, id) in value {
                context.writers[id as! YObjectID.RawValue] = { newID in // newID
                    takeValues[mkey] = newID
                    if takeValues.count == value.count { map._setValue(YOpaqueMap(takeValues), for: key) }
                }
            }
        }
    }
    
    public func smartCopy() -> Self {
        // [old:new]
        let context = YObject.SmartCopyContext()
        YObject.initContext = .smartcopy(context)
        
        let copied = self.copy()
                
        for (oldID, writer) in context.writers {
            let newID = context.table[oldID] ?? oldID
            writer(newID)
        }
        
        return copied
    }
}
