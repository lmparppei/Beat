//
//  BeatBackup.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 5.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

class BeatBackupFile:NSObject {
	@objc var name:String!
	@objc var date:Date!
	@objc var path:String!
	
	init (name:String, date:Date, path:String) {
		super.init()
		self.name = name
		self.date = date
		self.path = path
	}
}

class BeatBackup:NSObject {
	@objc class var backupURLKey:String { return "Backup URL" }
	
	class var separator:String {
		return " Backup "
	}
	
	class var backupURL:URL {
		// Check if there is an external URL set
		let backupPath:String = BeatUserDefaults.shared().get(BeatBackup.backupURLKey) as? String ?? ""
		if (backupPath.count > 0) {
			if FileManager.default.fileExists(atPath: backupPath) {
				return URL(fileURLWithPath: backupPath)
			}
		}
		
		let delegate = NSApp.delegate as! BeatAppDelegate
		return delegate.appDataPath("Backup")
	}
	
	class var formatter:DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH.mm"
		return dateFormatter
	}
	
	@objc class func backup (documentURL:URL, name:String) -> Bool {
		let date = documentURL.modificationDate
		let backupFolderURL = BeatBackup.backupURL
		let delegate = NSApp.delegate as! BeatAppDelegate
		
		if (date == nil) { return false }
		
		let dateFormatter = BeatBackup.formatter
		let backupName = name + BeatBackup.separator + dateFormatter.string(from: date!) + ".fountain"
		
		var result = false
		var backupURL = URL(fileURLWithPath: backupFolderURL.path)
		backupURL.appendPathComponent(backupName)
		
		let fm = FileManager.default
		
		do {
			if (fm.fileExists(atPath: backupURL.path)) {
				//_ = try fm.removeItem(at: backupURL)
				let tempURL = URL(fileURLWithPath: delegate.pathForTemporaryFile(withPrefix: "Backup"))
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
			BeatBackup.manageBackups(url: backupFolderURL)
		}
		return result
	}
	
	@objc class func backups (name:String) -> Array<BeatBackupFile> {
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
	
	@objc class func openBackupFolder() {
		let url = BeatBackup.backupURL
		NSWorkspace.shared.open(url)
	}
	
	class func getBackups() -> Dictionary<String, Array<BeatBackupFile>>? {
		var backupFiles:[String: Array<BeatBackupFile>] = Dictionary()
		let url = BeatBackup.backupURL
		
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
	
	class func manageBackups(url:URL) {
		// Keep maximum of 10 versions
		let fm = FileManager.default
		let backups = BeatBackup.getBackups()
		if (backups == nil) { return }
		
		for name in backups!.keys {
			var versions = backups![name]
			if (versions == nil) { continue }
			
			versions!.sort { backup1, backup2 in
				(backup1.date < backup2.date)
			}
			
			if (versions!.count > 10) {
				while (versions!.count > 10) {
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
		let openPanel = NSOpenPanel()
		openPanel.canChooseDirectories = true
		openPanel.canCreateDirectories = true
		openPanel.canChooseFiles = false
		
		let response = openPanel.runModal()
		
		if response == .OK && openPanel.url != nil {
			BeatUserDefaults.shared().save(openPanel.url!.absoluteString, forKey: BeatBackup.backupURLKey)
		}
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
