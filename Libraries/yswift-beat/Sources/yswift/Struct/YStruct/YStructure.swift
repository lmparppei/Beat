//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

class YStructure {
    let id: YIdentifier
    var length: Int
    
    init(id: YIdentifier, length: Int) {
        self.id = id
        self.length = length
    }

    var deleted: Bool { fatalError() }

    func merge(with right: YStructure) -> Bool { return false }

    func encode(into encoder: any YUpdateEncoder, offset: Int) { fatalError() }

    func integrate(transaction: YTransaction, offset: Int) throws -> Void { fatalError() }
    
    func getMissing(_ transaction: YTransaction, store: YStructStore) -> Int? { nil }
}

extension YStructure {
    func slice(diff: Int) -> YStructure { // no Skip return
        let left = self
        
        if left is YGC {
            let client = left.id.client, clock = left.id.clock
            return YGC(id: YIdentifier(client: client, clock: clock + diff), length: left.length - diff)
        } else if left is YSkip {
            let client = left.id.client, clock = left.id.clock
            return YSkip(id: YIdentifier(client: client, clock: clock + diff), length: left.length - diff)
        } else {
            let leftItem = left as! YItem
            let client = leftItem.id.client, clock = leftItem.id.clock
            
            return YItem(
                id: YIdentifier(client: client, clock: clock + diff),
                left: nil,
                origin: YIdentifier(client: client, clock: clock + diff - 1),
                right: nil,
                rightOrigin: leftItem.rightOrigin,
                parent: leftItem.parent,
                parentSub: leftItem.parentKey,
                content: leftItem.content.splice(diff)
            )
        }
    }

    static func tryMerge(withLeft structs: RefArray<YStructure>, pos: Int) {
        let left = structs[pos - 1]
        let right = structs[pos]
        
        if left.deleted == right.deleted && type(of: left) == type(of: right) {
            if left.merge(with: right) {
                structs.value.remove(at: pos)
                if right is YItem
                    && (right as! YItem).parentKey != nil
                    && ((right as! YItem).parent!.object!).storage[(right as! YItem).parentKey!] === right
                {
                    ((right as! YItem).parent!.object!).storage[(right as! YItem).parentKey!] = (left as! YItem)
                }
            }
        }
    }
}
