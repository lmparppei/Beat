//
//  iOSDocument.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatParsing
import BeatCore
import QuickLook

@objc protocol iOSDocumentDelegate {
	var parser:ContinuousFountainParser? { get }
	func text() -> String!
	func contentForSaving() -> String!
	func createDocumentFile() -> String!
}

class iOSDocument: UIDocument {
    
	@objc var rawText:String = ""
	@objc var settings:BeatDocumentSettings = BeatDocumentSettings()
	@objc var delegate:iOSDocumentDelegate?
	@objc var parser:ContinuousFountainParser {
		return self.delegate?.parser ?? ContinuousFountainParser()
	}
	
	override var description: String {
		return fileURL.deletingPathExtension().lastPathComponent
	}
	
    override func contents(forType typeName: String) throws -> Any {
		guard let text = delegate?.createDocumentFile() ?? delegate?.text() else {
			fatalError("ERROR: Could not save the file. We'll quit the app to avoid data loss.")
		}
		return text.data(using: .utf8) as Any
    }
	
	override func save(to url: URL, for saveOperation: UIDocument.SaveOperation) async -> Bool {
		let success = await super.save(to: url, for: saveOperation)
		let backup = BeatBackup.backup(documentURL: url, name: self.fileURL.deletingPathExtension().lastPathComponent)
		if !backup {
			print("Backup failed")
		}
		
		return success
	}
		
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
		rawText = String(data: contents as! Data, encoding: .utf8) ?? ""
		rawText = rawText.replacingOccurrences(of: "\r", with: "")
		
		// Read settings and replace range
		let range = settings.readAndReturnRange(rawText)
		if (range.length > 0) {
			rawText = rawText.stringByReplacing(range: range, withString: "")
		}
		
		//setupHandoff()
    }
	
	override func close() async -> Bool {
		self.userActivity?.resignCurrent()
		return await super.close()
	}
		
	@objc func rename(newName:String) {
		
	}
	
	@objc func copyFileToAppStorage() throws -> URL {
		let fileManager = FileManager.default
		
		// Get the destination URL in the app's internal storage
		guard let destinationURL = fileManager
			.urls(for: .documentDirectory, in: .userDomainMask)
			.first?
			.appendingPathComponent(self.fileURL.lastPathComponent) else {
				throw NSError(domain: "YourAppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create destination URL"])
		}
		
		// Copy the file to the app's internal storage
		do {
			try fileManager.copyItem(at: self.fileURL, to: destinationURL)
			return destinationURL
		} catch {
			throw error
		}
	}

	func moveFileToDocumentPickerScope(fileURL: URL, newName: String) throws -> URL {
		let fileManager = FileManager.default
		
		// Get the destination URL in the document picker scope (e.g., Documents folder)
		guard let destinationURL = fileManager
			.urls(for: .documentDirectory, in: .userDomainMask)
			.first?
			.appendingPathComponent(newName) else {
				throw NSError(domain: "YourAppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create destination URL"])
		}
		
		// Move the file to the document picker scope
		do {
			try fileManager.moveItem(at: fileURL, to: destinationURL)
			return destinationURL
		} catch {
			throw error
		}
	}
	
	var canRename:Bool {
		let documentURL = self.fileURL.standardizedFileURL
		let localDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		
		if localDocumentsURL != nil && documentURL.path.hasPrefix(localDocumentsURL!.path) {
			// Yes, we can rename documents in our local storage
			return true
		} else {
			return false
		}
	}
	
	@objc func renameDocument(to newTitle: String) {
		let fileURL = self.fileURL
		
		let fileManager = FileManager.default
		let directoryURL = fileURL.deletingLastPathComponent()
		let newFileURL = directoryURL.appendingPathComponent(newTitle)
		
		let coordinator = NSFileCoordinator()
		
		if !fileURL.startAccessingSecurityScopedResource() {
			print("ERROR accessing url", self.fileURL)
			return
		}

		coordinator.coordinate(writingItemAt: fileURL, options: .forMoving, error: nil) { (newURL) in
			do {
				try fileManager.moveItem(at: fileURL, to: newFileURL)
				self.presentedItemDidMove(to: newFileURL)

				self.updateChangeCount(.done)
				
				fileURL.stopAccessingSecurityScopedResource()
			} catch {
				// Handle the error
				print("Failed to rename document: \(error)", fileURL)
			}
		}
	}
	
	/// Check if the file is stored on a cloud service
	func isDocumentInCloud(fileURL: URL) -> Bool {
		do {
			let resourceValues = try fileURL.resourceValues(forKeys: [.isUbiquitousItemKey])
			return resourceValues.isUbiquitousItem ?? false
		} catch {
			print("Error checking if document is in cloud: \(error)")
			return false
		}
	}
	/// Check that the document is actually fully uploaded in the cloud
	func isDocumentFullyUploaded(fileURL: URL) -> Bool {
		do {
			let resourceValues = try fileURL.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey])
			return resourceValues.ubiquitousItemIsUploaded ?? false
		} catch {
			print("Error checking if document is fully downloaded: \(error)")
			return false
		}
	}
	
	func checkDocumentCloudStatus(fileURL: URL) {
		let inCloud = isDocumentInCloud(fileURL: fileURL)
		let fullyDownloaded = isDocumentFullyUploaded(fileURL: fileURL)
		
		print("""
			  Document Status:
			  - In iCloud: \(inCloud)
			  - Fully Downloaded: \(fullyDownloaded)
			  """)
	}
	
	
	// MARK: - Handoff
	/*
	@objc func setupHandoff() {
		let activity = NSUserActivity(activityType: "fi.KAPITAN.Beat.editing")
		activity.title = "Editing Document"
		activity.isEligibleForHandoff = true
		activity.isEligibleForSearch = true
		activity.isEligibleForPublicIndexing = false
		
		activity.userInfo = ["url": self.fileURL.absoluteString]
		
		self.userActivity = activity
		activity.becomeCurrent()
	}
	
	override func updateUserActivityState(_ userActivity: NSUserActivity) {
		super.updateUserActivityState(userActivity)
		userActivity.addUserInfoEntries(from: [
			"url": self.fileURL.absoluteString
		])
		self.userActivity?.becomeCurrent()
	}
	 */
}

