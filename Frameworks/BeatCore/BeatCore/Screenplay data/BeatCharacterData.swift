//
//  BeatCharacterData.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 24.12.2023.
//

import Foundation

struct BeatCharacter {
    var host:BeatCharacterData?
    
    var name:String = "" { didSet { self.host?.updateData() } }
    var aliases:Set<String> = [] { didSet { self.host?.updateData() } }
    var bio:String = "" { didSet { self.host?.updateData() } }
    var age:String = "" { didSet { self.host?.updateData() } }
    var gender:String = "" { didSet { self.host?.updateData() } }
    var highlightColor:String = "" { didSet { self.host?.updateData() } }
    var linked:String? { didSet { self.host?.updateData() } }
    
    var dictionary:[String:Any] {
        get {
            var dict:[String:Any] = [:]
            
            // We don't want any empty keys left in the dict to save file space, so... yeah.
            if aliases.count > 0 { dict["aliases"] = aliases }
            if bio.count > 0 { dict["bio"] = bio }
            if age.count > 0 { dict["age"] = age }
            if gender.count > 0 { dict["gender"] = gender }
            if highlightColor.count > 0 { dict["highlightColor"] = highlightColor }
            if linked != nil { dict["linked"] = linked! }
            
            return dict
        }
    }
}

class BeatCharacterData:NSObject {
 
    var characters:[BeatCharacter]
    weak var delegate:BeatEditorDelegate?
    
    /// Set to true if you want to avoid updating the data on every change
    var processing = false
 
    @objc public init(delegate: BeatEditorDelegate) {
        self.characters = []
        self.delegate = delegate
        
        super.init()
    }

    /// Updates character data in document settings. We want plugins to always be able to access the JSON.
    @objc public func updateData() {
        if self.processing {
            // We are in the middle of a larger process, so don't create the JSON.
            return
        }
        
        // A list of linked characters we need to handle later
        var linkedCharacters:[BeatCharacter] = []
        
        // JSON structure is CharacterName: [Key: Value]
        var dict:[String:[String:Any]] = [:]
        
        for character in characters {
            if character.linked != nil {
                linkedCharacters.append(character)
                continue
            } else if character.name.count == 0 {
                continue
            }
            
            // Store to dictionary
            dict[character.name] = character.dictionary
        }
        
        // Make sure we handled all the linked characters correctly
        for linkedCharacter in linkedCharacters {
            if let link = linkedCharacter.linked, let actualCharacter = dict[link] {
                var aliases = actualCharacter["aliases"] as? Set<String>
                aliases?.insert(link)
            }
        }
        
        // Save data to document settings
        self.delegate?.documentSettings.set(DocSettingCharacterData, as: dict)
    }
}
