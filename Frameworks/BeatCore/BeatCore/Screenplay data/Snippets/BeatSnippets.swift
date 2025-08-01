//
//  BeatSnippets.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 2.6.2025.
//

public struct BeatSnippet {
    public var title:String
    public var text:String
    public var color:String?
    public var UUID:String?
    
    public init(dict:[String:String]) {
        self.title = dict["title"] ?? ""
        self.text = dict["text"] ?? ""
        self.color = dict["color"] ?? ""
        self.UUID = dict["UUID"] ?? NSUUID().uuidString
    }
    
    init(title: String, text: String, color: String? = nil) {
        self.title = title
        self.text = text
        self.color = color
        self.UUID = NSUUID().uuidString
    }
    
    func asDict() -> [String:String] {
        return [
            "title": title,
            "text": text,
            "color": color != nil ? color! : ""
        ]
    }
}

@objc public class BeatSnippets:NSObject {
    weak var editor:BeatEditorDelegate?
    
    public init(editor: BeatEditorDelegate) {
        self.editor = editor
        super.init()
    }
    
    public func library() -> [BeatSnippet] {
        guard let editor,
              let items = editor.documentSettings.get("Snippets") as? [[String:String]]
        else {
            print("WARNING: No editor or library for snippets")
            return []
        }
        
        var library:[BeatSnippet] = []
        
        for item in items {
            let snippet = BeatSnippet(dict: item)
            library.append(snippet)
        }
        
        return library
    }
    
    func saveLibrary(_ library:[BeatSnippet]) {
        var items:[[String:String]] = []
        
        for item in library {
            items.append(item.asDict())
        }
        
        self.editor?.documentSettings.set("Snippets", as: items)
    }
    
    func indexForSnippet(UUID:String) -> Int {
        let lib = self.library()
        
        for i in 0..<lib.count {
            let item = lib[i]
            
            if item.UUID == UUID {
                return i
            }
        }

        return NSNotFound
    }
    
    func addSnippet(text:String) {
        var lib = self.library()
        
        let snippet = BeatSnippet(title: "", text: text)
        lib.append(snippet)
        
        saveLibrary(lib)
    }
    
    func deleteSnippet(UUID:String) {
        var lib = self.library()
        
        for i in 0..<lib.count {
            let item = lib[i]
            guard let itemUUID = item.UUID, itemUUID == UUID else { continue }
            
            lib.remove(at: i)
            break
        }
        
        saveLibrary(lib)
    }
    
    func reorder(from:Int, to:Int) {
        var lib = self.library()
        lib.moveElement(from: from, toBefore: to)
        saveLibrary(lib)
    }
    
    func updateSnippet(UUID:String, title:String, text:String, color:String?) {
        let idx = indexForSnippet(UUID: UUID)
        guard idx != NSNotFound else {
            print("Snippet not found")
            return
        }
        
        var lib = library()
        var item = lib[idx]
        
        item.text = text
        item.title = title
        item.color = color
        
        lib[idx] = item
        
        saveLibrary(lib)
    }
}

extension Array {
    mutating func moveElement(from fromIndex: Int, toBefore toIndex: Int) {
        guard fromIndex != toIndex && fromIndex + 1 != toIndex,
              indices.contains(fromIndex),
              (0...count).contains(toIndex) else {
            return
        }

        let element = self[fromIndex]
        remove(at: fromIndex)

        // Adjust target index if element was before the destination
        let adjustedToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        insert(element, at: adjustedToIndex)
    }
}
