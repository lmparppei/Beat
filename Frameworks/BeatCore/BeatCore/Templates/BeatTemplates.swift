//
//  BeatTemplates.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

public struct BeatTemplateFile {
    public var filename:String
    public var title:String
    public var description:String
    public var icon:String?
    public var url:URL?
    public var product:String? /// The filename this template produces (ie. Tutorial iOS.fountain -> Tutorial.fountain)
    
    public init(filename: String, title: String, description: String, icon: String? = nil, url: URL? = nil, product: String?) {
        self.filename = filename
        self.title = title
        self.description = description
        self.icon = icon
        self.url = url
        self.product = product
    }
}

/// Singleton class which provides templates
@objc public final class BeatTemplates:NSObject {
	var _allTemplates:[String:[BeatTemplateFile]]?
	
	private static var sharedTemplates:BeatTemplates = {
		return BeatTemplates()
	}()
	
    @objc class public func shared() -> BeatTemplates {
		return sharedTemplates
	}
    
    @objc public func getTemplateURL(filename:String) -> URL? {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: filename, withExtension: "fountain")
        print(" ... ", url, filename)
        return url
    }
	
	/// Returns the full template data
	public func getTemplates() -> [String:[BeatTemplateFile]] {
		if _allTemplates != nil { return _allTemplates! }
		
		// get the plist file
		let bundle = Bundle(for: type(of: self))
		
		guard let url = bundle.url(forResource: "Templates And Tutorials", withExtension: "plist") else { return [:] }
		do {
			// Get the template plist file
			let data = try Data(contentsOf: url)
			guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String:[[String:String]]] else { return [:] }
			
			var templateData:[String:[BeatTemplateFile]] = [:]
			
			for key in plist.keys {
				guard let templates = plist[key] else { continue }
				
				// Initialize array for different template types if needed
				if templateData[key] == nil { templateData[key] = [] }
				
				for template in templates {
                    // Skip OS-specific templates.
                    if template["target"] != nil {
                        #if os(macOS)
                            if template["target"] != "macOS" { continue }
                        #else
                            if template["target"] != "iOS" { continue }
                        #endif
                    }
                    
                    // Check if the file actually exist before adding it
					if let url = bundle.url(forResource: template["filename"], withExtension: nil) {
						// Add the localized template to array
						let t = BeatTemplateFile(filename: template["filename"] ?? "", title: BeatLocalization.localizedString(forKey: template["title"] ?? ""), description: BeatLocalization.localizedString(forKey: template["description"] ?? ""), icon: template["icon"] ?? "", url: url, product: template["product"])
						templateData[key]?.append(t)
                    }
				}
			}
		
			return templateData
			
		} catch {
			print("Template data could not be loaded.")
			return [:]
		}
	}
	
	public class func forFamily(_ family:String) -> [BeatTemplateFile] {
		return BeatTemplates.shared().forFamily(family)
	}
	public func forFamily(_ family:String) -> [BeatTemplateFile] {
		if _allTemplates == nil { _allTemplates = self.getTemplates() }
		
		return _allTemplates?[family] ?? []
	}
	
	public class func families() -> [String] {
		return BeatTemplates.shared().families()
	}
	public func families() -> [String] {
		let templates = getTemplates()
		let keys:[String] = templates.keys.map({ $0 })
		return keys
	}
}
