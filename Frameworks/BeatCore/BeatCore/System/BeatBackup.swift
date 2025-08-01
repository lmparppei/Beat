//
//  BeatBackup.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 5.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

fileprivate var autosaveCopies = 30
fileprivate var backupCopies = 30

@objc
public class BeatBackupFile:NSObject {
	@objc public var name:String!
	@objc public var date:Date!
	@objc public var path:String!
	
    @objc public init (name:String, date:Date, path:String) {
		super.init()
		self.name = name
		self.date = date
		self.path = path
	}
}

@objc
public class BeatBackup:NSObject {
	@objc class var backupURLKey:String { return "backupURL" }
	@objc class var bookmarkKeyBackup:String { return "backupBookmark"}
	@objc class var bookmarkKeyAutosave:String { return "autosaveBookmark"}
	
	class var separator:String { return " Backup " }
	class var defaultURL:URL {
		return BeatPaths.appDataPath("Backup")
	}
	class var defaultAutosaveURL:URL {
		var url = BeatBackup.defaultURL
		url = url.appendingPathComponent("Autosave/")
		return url
	}

	public class var backupURL:URL {
		// Check if there is an external URL set
		let backupPath:String = BeatUserDefaults.shared().get(BeatBackup.backupURLKey) as? String ?? ""
		let backupURL = URL(fileURLWithPath: backupPath)
		
		if backupPath.count > 0  {
			// Return the URL if we can resolve it
			if let url = BeatBackup.resolve(url: backupURL, key: BeatBackup.bookmarkKeyBackup) { return url }
		}
				
		return BeatBackup.defaultURL
	}
	
    public class var autosaveURL:URL {
		// Check if there is an external URL set
		let backupPath:String = BeatUserDefaults.shared().get(BeatBackup.backupURLKey) as? String ?? ""
		let autosaveURL = URL(fileURLWithPath: backupPath + "/Autosave/")
		
		if backupPath.count > 0  {
			// Return the URL if we can resolve it
			if let url = BeatBackup.resolve(url: autosaveURL, key: BeatBackup.bookmarkKeyAutosave) { return url }
		}
		
		// Return default sandbox container URL
		return BeatBackup.defaultURL.appendingPathComponent("Autosave/")
	}
	
	class func resolve(url:URL, key:String) -> URL? {
		if let bookmark = BeatBackup.hasBookmark(for: url, key: key) {
			var stale = false
			do {
                #if os(macOS)
				return try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
                #else
                return try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
                #endif
			} catch {
				print("Failed to retrieve autosave bookmark for", url)
			}
		}
		
		return nil
	}
	
	/// Try to access the backup URL
	class func hasAccess(to url:URL, key:String) -> Bool {
		if BeatBackup.hasBookmark(for: url, key: key) != nil {
			if FileManager.default.fileExists(atPath: url.path) {
				return true
			}
		}
		
		return false
	}
	
	/// Tries to access the bookmarked URL
	@objc class func hasBookmark(for url:URL, key:String) -> Data? {
		guard let bookmark = UserDefaults.standard.data(forKey: key) else {
			// No bookmark data, forget about it
			return nil
		}
		
		var isStale = false;
		
		do {
            #if os(macOS)
			_ = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale);
            #else
            _ = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            #endif
		} catch {
			print("WARNING: Can't access the bookmark")
		}
		
		if (!isStale) { return bookmark }
		else { return nil }
	}
    
	/// Tries to gain access to a new backup URL
	@objc public class func bookmarkBackupFolder(url: URL) -> Data? {
		do {
            #if os(macOS)
			let backupBookmark = try url.bookmarkData(options: [.withSecurityScope])
            #else
            let backupBookmark = try url.bookmarkData()
            #endif
			UserDefaults.standard.set(backupBookmark, forKey: BeatBackup.bookmarkKeyBackup)
			
			// Create autosave subfolder for later use
			var autosaveURL = url
			autosaveURL.appendPathComponent("Autosave/")
			
			// Create folder
			try FileManager.default.createDirectory(at: autosaveURL, withIntermediateDirectories: true)
			
            #if os(macOS)
			let autosaveBookmark = try autosaveURL.bookmarkData(options: [.withSecurityScope])
            #else
            let autosaveBookmark = try autosaveURL.bookmarkData()
            #endif
			UserDefaults.standard.set(autosaveBookmark, forKey: BeatBackup.bookmarkKeyAutosave)
						
			return backupBookmark
		} catch {
			print("ERROR: Unable to access backup url")
			return nil
		}
	}
	
	class var formatter:DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH.mm"
		return dateFormatter
	}
	
	@objc public class func autosaveCopy (documentURL:URL, name:String) -> Bool {
		return backup(documentURL: documentURL, name: name, autosave: true)
	}
    
	@objc public class func backup (documentURL:URL, name:String, autosave:Bool = false) -> Bool {
		let fm = FileManager.default

		let date = documentURL.modificationDate
		var backupFolderURL = (autosave) ? BeatBackup.autosaveURL : BeatBackup.backupURL
		
		// If we are outside the sandbox, start accessing resources
		if ((!autosave && backupFolderURL != BeatBackup.defaultURL) || (autosave && backupFolderURL != BeatBackup.defaultAutosaveURL)) {
			if !backupFolderURL.startAccessingSecurityScopedResource() {
				print(" ... failed to open autosave url", backupFolderURL)
				backupFolderURL = (autosave) ? BeatBackup.defaultAutosaveURL : BeatBackup.defaultURL
			}
		}
		
		let prefix = (autosave) ? "Autosave" : "Backup"
		
		if (date == nil) { return false }
		
		let dateFormatter = BeatBackup.formatter
		let backupName = name + BeatBackup.separator + dateFormatter.string(from: date!) + ".fountain"
		
		var result = false
		var backupURL = URL(fileURLWithPath: backupFolderURL.path)
		backupURL.appendPathComponent(backupName)
				
		do {
			// Make sure the folder exists
			if !fm.fileExists(atPath: backupFolderURL.path) {
				try fm.createDirectory(at: backupURL, withIntermediateDirectories: true)
			}

			if (fm.fileExists(atPath: backupURL.path)) {
				//_ = try fm.removeItem(at: backupURL)
				let tempURL = URL(fileURLWithPath: BeatPaths.pathForTemporaryFile(withPrefix: prefix))

				try fm.copyItem(at: documentURL, to: tempURL)
				try fm.replaceItem(at: backupURL, withItemAt: tempURL, backupItemName: name, resultingItemURL: nil)

				result = true
			} else {
				try fm.copyItem(at: documentURL, to: backupURL)
				result = true
			}

		} catch let error as NSError {
			print("Backup failed", error)
			result = false
		}
		
		if (result == true) {
			// Remove old backups if the backup was successful
			if autosave {
				BeatBackup.manageBackups(url: backupFolderURL, autosave: true)
			} else {
				BeatBackup.manageBackups(url: backupFolderURL)
			}
		}
		
		// If we are outside the sandbox, stop accessing resources
		if (backupFolderURL != BeatBackup.defaultURL) {
			backupFolderURL.stopAccessingSecurityScopedResource()
		}
		return result
	}
	
	@objc public class func backups (name:String) -> Array<BeatBackupFile> {
		let backups = getBackups()
		if (backups == nil) { return [] }
		
		if (backups![name] == nil) {
			return []
		}
		else {
			var result = backups![name]
			
			result!.sort { backup1, backup2 in
				(backup1.date < backup2.date)
			}
			return result!
		}
	}
	
	@objc public class func openBackupFolder() {
        #if os(macOS)
		let url = BeatBackup.backupURL
		NSWorkspace.shared.open(url)
        #endif
	}

	@objc public class func getBackups(autosavedCopies:Bool = false) -> Dictionary<String, Array<BeatBackupFile>>? {
		var backupFiles:[String: Array<BeatBackupFile>] = Dictionary()
		let url = (autosavedCopies) ? BeatBackup.autosaveURL : BeatBackup.backupURL
		
		do {
			let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
			
			for file in files {
				let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
				let r = filename.range(of: BeatBackup.separator)
				if (r == nil) { continue }
				
				let range = NSRange(r!, in: file)
				let actualName = filename.substring(range: NSMakeRange(0, range.location))
								
				let dateStr = filename.substring(range: NSMakeRange(NSMaxRange(range), filename.count - NSMaxRange(range)))
				
				let formatter = BeatBackup.formatter
				let date = formatter.date(from: dateStr)
				
				if backupFiles[actualName] == nil {
					backupFiles[actualName] = []
				}
				
				// Don't allow nil values
				if (date == nil || actualName.count == 0) {
					continue
				}
				
				var backupURL = URL(fileURLWithPath: url.path)
				backupURL.appendPathComponent(file)
				
				let backup = BeatBackupFile(name: actualName, date: date!, path: backupURL.path)
				backupFiles[actualName]?.append(backup)
			}
		} catch let error as NSError {
			print("Can't open backup folder", error)
		}
		
		return backupFiles
	}
	
	class func manageAutosaves(url:URL) {
		BeatBackup.manageBackups(url: url, autosave: true)
	}
	
	class func manageBackups(url:URL, autosave:Bool = false) {
		// Keep maximum of 10 versions of backups and 20 versions of autosaves
		let backupCount = (autosave) ? autosaveCopies : backupCopies
		
		let fm = FileManager.default
		let backups = BeatBackup.getBackups(autosavedCopies: autosave)
		
		if (backups == nil) { return }
		
		for name in backups!.keys {
			var versions = backups![name]
			if (versions == nil) { continue }
			
			versions!.sort { backup1, backup2 in
				(backup1.date < backup2.date)
			}
			
			if (versions!.count > backupCount) {
				while (versions!.count > backupCount) {
					let oldVersion = versions!.first
					do {
						versions?.removeFirst()
						try fm.removeItem(at: URL(fileURLWithPath: oldVersion!.path))
					} catch let error as NSError { print("Error removing backup", oldVersion?.path ?? "(none)", error) }
				}
			}
		}
	}
	
	class func selectBackupFolder() {
        #if os(macOS)
		let openPanel = NSOpenPanel()
		openPanel.canChooseDirectories = true
		openPanel.canCreateDirectories = true
		openPanel.canChooseFiles = false
		
		let response = openPanel.runModal()
		
		if response == .OK && openPanel.url != nil {
			BeatUserDefaults.shared().save(openPanel.url!.absoluteString, forKey: BeatBackup.backupURLKey)
		}
        #endif
	}
}

extension URL {
	var attributes: [FileAttributeKey : Any]? {
		do {
			return try FileManager.default.attributesOfItem(atPath: path)
		} catch let error as NSError {
			print("FileAttribute error: \(error)")
		}
		return nil
	}

	var fileSize: UInt64 {
		return attributes?[.size] as? UInt64 ?? UInt64(0)
	}

	var fileSizeString: String {
		return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
	}

	var modificationDate: Date? {
		return attributes?[.modificationDate] as? Date
	}
	
	var creationDate: Date? {
		return attributes?[.creationDate] as? Date
	}
}

/*
 
 At the closest point of our intimacy,
 we were just 0.01cm from each other.
 
 */
