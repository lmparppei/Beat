//
//  BeatCharacterData.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 24.12.2023.
//

import Foundation

@objc public protocol BeatCharacterExports:JSExport {
    @objc var name:String { get set }
    @objc var aliases:[String] { get set }
    @objc var bio:String { get set }
    @objc var age:String { get set }
    @objc var gender:String { get set }
    
    @objc var lines:Int { get }
    @objc var scenes:[Line] { get }
    
    @objc var dictionary:[String:Any] { get }
}

@objc public class BeatCharacter:NSObject, BeatCharacterExports
{
    @objc public var name:String
    @objc public var aliases:[String]
    @objc public var bio:String
    @objc public var age:String
    @objc public var gender:String = "unspecified"
    @objc public var highlightColor:String
    @objc public var realName:String?
    
    /// Set `true` when this name is NOT found in the actual screenplay
    @objc public var notPresentInScreenplay = false
    
    /// Number of lines
    @objc public var lines:Int = 0
    @objc public var scenes:[Line] = []
    
    public var dictionary:[String:Any] {
        get {
            // Return empty dict if no real data was set
            if aliases.count == 0 && age.count == 0 && (gender.count == 0 || gender == "unspecified") && realName == nil && highlightColor.count == 0 {
                return [:]
            }
            
            var dict:[String:Any] = [:]
            
            // We don't want any empty keys left in the dict to save file space, so... yeah.
            if name.count > 0 { dict["name"] = name }
            if aliases.count > 0 { dict["aliases"] = aliases }
            if bio.count > 0 { dict["bio"] = bio }
            if age.count > 0 { dict["age"] = age }
            if gender.count > 0 { dict["gender"] = gender }
            if highlightColor.count > 0 { dict["highlightColor"] = highlightColor }
            if (realName ?? "").count > 0 { dict["realName"] = realName! }
            
            return dict
        }
    }
    
    @objc public init(name: String = "", aliases: [String] = [], bio: String = "", age: String = "", gender: String = "", highlightColor: String = "", realName: String? = nil, lines: Int = 0, scenes: [Line] = [] ) {
        self.name = name
        self.aliases = aliases
        self.bio = bio
        self.age = age
        self.gender = (gender.count > 0) ? gender : "unspecified"
        self.highlightColor = highlightColor
        self.realName = ((realName ?? "").count > 0) ? realName : nil
        self.lines = lines
        self.scenes = scenes
        
        super.init()
    }
    
    public static func readData(_ dict:[String:Any]) -> BeatCharacter {
        let character = BeatCharacter()
        
        character.name = (dict["name"] as? String) ?? ""
        character.aliases = dict["aliases"] as? [String] ?? []
        character.bio = (dict["bio"] as? String) ?? ""
        character.age = (dict["age"] as? String) ?? ""
        character.gender = (dict["gender"] as? String) ?? character.gender
        character.highlightColor = (dict["highlightColor"] as? String) ?? ""
        character.realName = (dict["realName"] as? String) ?? ""
        
        return character
    }
}

@objc public protocol BeatCharacterDataExports:JSExport {
    @objc func allCharactersAndLines() -> [String:BeatCharacter]
    @objc func characters() -> [String:BeatCharacter]
    @objc func saveCharacter(_ character:BeatCharacter)
    @objc var characterData:[String:[String:Any]]? { get }
}

@objc public class BeatCharacterData:NSObject, BeatCharacterDataExports {
    weak var delegate:BeatEditorDelegate?
    
    /// Set to true if you want to avoid updating the data on every change
    @objc public var processing = false
 
    @objc public init(delegate: BeatEditorDelegate) {
        self.delegate = delegate
        super.init()
        
        // Let's convert legacy values right at init
        convertGendersToNewModelIfNeeded()
    }
    
    /// Alias for `charactersAndLines` for more sensible JS export
    @objc public func allCharactersAndLines() -> [String:BeatCharacter] {
        return charactersAndLines()
    }
    
    /// Gets stored character data, collects EVERY character name from screenplay, stores the number of lines and scenes for each character and returns a dictionary with names mapped to character object.
    @objc public func charactersAndLines(lines providedLines:[Line] = []) -> [String:BeatCharacter] {
        guard let parser = self.delegate?.parser else { return [:] }
        
        let lines = (providedLines.count > 0) ? providedLines : parser.safeLines() as? [Line] ?? []
        
        // First get any stored character data and merge
        var characters = self.characters()
        
        // Then gather all known aliases
        var aliases:[String:String] = [:]
        for name in characters.keys {
            if let character = characters[name], character.aliases.count > 0 {
                for alias in character.aliases {
                    aliases[alias.uppercased()] = character.name
                }
            }
        }
        
        var currentScene:Line?
        
        for line in lines {
            if line.type == .heading { currentScene = line }
            if !line.isAnyCharacter() { continue }
            
            let name = line.characterName() ?? ""
            if name.count > 0 {
                // Set real name based on alias if needed
                let realName = (aliases[name] == nil) ? name : aliases[name]!
                
                // Create the character data element for non-existent characters
                if characters[realName] == nil {
                    characters[realName] = BeatCharacter(name:realName)
                }
                
                let character = characters[realName]
                character?.lines += 1
                
                if let currentScene, let character, !character.scenes.contains(currentScene) {
                    character.scenes.append(currentScene)
                }
            }
        }
        
        for name in characters.keys {
            if let character = characters[name] {
                if character.lines == 0 {
                    characters.removeValue(forKey: name)
                    removeCharacter(name: name)
                }
            }
        }
        
        return characters
    }
    
    /// Returns a dictionary of characters mapped to actual character object.
    /// - note: This will NOT include every character in the screenplay, only the ones that have stored character data.
    @objc public func characters() -> [String:BeatCharacter] {
        guard let data = self.characterData else { return [:] }
        var characters:[String:BeatCharacter] = [:]
        
        for name in data.keys {
            if let dict = data[name] {
                let character = BeatCharacter.readData(dict)
                characters[name] = character
            }
        }
        
        return characters
    }
    
    @objc public func saveCharacter(_ character:BeatCharacter) {
        var characters = self.characters()
        characters[character.name.uppercased()] = character
        updateData(with: characters)
    }
    
    /// Updates character data in document settings. We want plugins to always be able to access the JSON.
    @objc public func updateData(with characters:[String:BeatCharacter]) {
        if self.processing {
            // We are in the middle of a larger process, so don't create the JSON.
            return
        }
        
        // A list of linked characters we need to handle later
        var linkedCharacters:[BeatCharacter] = []
        
        // JSON structure is CharacterName: [Key: Value]
        var dict:[String:[String:Any]] = [:]
        
        for name in characters.keys {
            guard let character = characters[name] else { continue }
            
            if character.name == "" { character.name = name }
            
            if (character.realName ?? "").count > 0  {
                linkedCharacters.append(character)
                continue
            } else if character.name.count == 0 {
                continue
            }
            
            // Store to dictionary if needed
            let charData = character.dictionary
            if charData.count > 0 {
                dict[character.name] = charData
            }
        }
        
        // Make sure we handled all the linked characters correctly
        for linkedCharacter in linkedCharacters {
            if let link = linkedCharacter.realName, let actualCharacter = dict[link] {
                var aliases = actualCharacter["aliases"] as? Set<String>
                aliases?.insert(link)
            }
        }
        
        // Save data to document settings
        self.delegate?.documentSettings.set(DocSettingCharacterData, as: dict)
        #if os(macOS)
        self.delegate?.updateChangeCount(.changeDone)
        #endif
        
        // Make sure the views reflect changes
        self.delegate?.updateEditorViewsInBackground()
    }
    
    public var characterData:[String:[String:Any]]? {
        return self.delegate?.documentSettings.get(DocSettingCharacterData) as? [String:[String:Any]]
    }
            
    /// Converts the old gender list to new character data model
    @objc public func convertGendersToNewModelIfNeeded() {
        guard let genders = self.delegate?.documentSettings.get(DocSettingCharacterGenders) as? [String:String] else { return }
        
        var dict:[String:[String:Any]] = [:]
        
        for name in genders.keys {
            let character = [
                "name": name.uppercased(),
                "gender": genders[name] ?? ""
            ]
            dict[name] = character
        }
        
        self.delegate?.documentSettings.set(DocSettingCharacterData, as: dict)
        self.delegate?.documentSettings.remove(DocSettingCharacterGenders)
    }
    
    @objc public func getCharacter(with name:String) -> BeatCharacter? {
        guard let dict = self.characterData?[name.uppercased()] else {
            return BeatCharacter(name: name)
        }
        
        return BeatCharacter.readData(dict)
    }
    
    public func addCharacter(name:String) {
        
    }
    
    public func removeCharacter(name:String) {
        guard var characters = self.characterData else { return }
        
        characters.removeValue(forKey: name)
        BeatUserDefaults.shared().save(characters, forKey: DocSettingCharacterData)
    }
}


