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
    @objc public var iCloud:Bool
    
    @objc public init (name:String, date:Date, path:String, iCloud:Bool = false) {
        self.iCloud = iCloud
        self.name = name
        self.date = date
        self.path = path

        super.init()
    }
}

@objc
public class BeatBackup:NSObject {
    @objc static let backupURLKey = "backupURL"
    @objc static let bookmarkKeyBackup = "backupBookmark"
    @objc static let bookmarkKeyAutosave = "autosaveBookmark"
    @objc static let separator:String = " Backup "
    
    // iCloud support
    @objc public class var iCloudBackupEnabled:Bool {
        get { return BeatUserDefaults.shared().getBool(BeatSettingiCloudBackupEnabled) }
        set { BeatUserDefaults.shared().save(newValue, forKey: BeatSettingiCloudBackupEnabled) }
    }
    @objc public class var iCloudAvailable:Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // MARK: URLs
    
    /// Basic root URL for on-device backups
    class var defaultURL:URL {
        return BeatPaths.appDataPath("Backup")
    }
    
    /// AppendedURL for autosaved files
    class var defaultAutosaveURL:URL {
        var url = BeatBackup.defaultURL
        url = url.appendingPathComponent("Autosave/")
        return url
    }
    
    /// Private container URL for iCloud backups
    class var iCloudContainerURL:URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
    
    /// Full URL for on-device backups
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
    
    class var iCloudBackupURL:URL? {
        guard let container = BeatBackup.iCloudContainerURL else { return nil }
        return container.appendingPathComponent("Documents/Backup", isDirectory: true)
    }
    
    class var iCloudAutosaveURL:URL? {
        return BeatBackup.iCloudBackupURL?.appendingPathComponent("Autosave/", isDirectory: true)
    }
    
    
    // MARK: Sandbox access
    
    /// Resolves a scoped bookmark or creates one
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
    
    
    // MARK: - On-device backup
    
    @objc public class func autosaveCopy (documentURL:URL, name:String) -> Bool {
        return backup(documentURL: documentURL, name: name, autosave: true)
    }
    
    
    /// Does a single on-device backup of the given document.
    /// - Parameter documentURL URL for the saved document (or temporary URL for autosaved copies)
    /// - Parameter name Last filename component for the document
    /// - Parameter autosave  Set `true` if this is called to do _autosave_ (non-saved state) and not a backup (when saving the document)
    @objc public class func backup (documentURL:URL, name:String, autosave:Bool = false) -> Bool {
        let fm = FileManager.default
        var backupFolderURL = (autosave) ? BeatBackup.autosaveURL : BeatBackup.backupURL
        
        // If we are outside the sandbox, start accessing resources
        if ((!autosave && backupFolderURL != BeatBackup.defaultURL) || (autosave && backupFolderURL != BeatBackup.defaultAutosaveURL)) {
            if !backupFolderURL.startAccessingSecurityScopedResource() {
                print(" ... failed to open autosave url", backupFolderURL)
                backupFolderURL = (autosave) ? BeatBackup.defaultAutosaveURL : BeatBackup.defaultURL
            }
        }
        
        // Create backup file filename + final URL
        let prefix = (autosave) ? "Autosave" : "Backup"
        
        let date = documentURL.modificationDate ?? Date()
        let dateFormatter = BeatBackup.formatter
        let backupName = name + BeatBackup.separator + dateFormatter.string(from: date) + ".fountain"
        
        var backupURL = URL(fileURLWithPath: backupFolderURL.path)
        backupURL.appendPathComponent(backupName)
        
        //
        var result = false
        
        do {
            // Make sure the folder exists
            if !fm.fileExists(atPath: backupFolderURL.path) {
                try fm.createDirectory(at: backupURL, withIntermediateDirectories: true)
            }
            
            // If the file exists, we need to replace it, otherwise it's enough to just copy it to the URL
            if (fm.fileExists(atPath: backupURL.path)) {
                // First move the file to a temp URL
                let tempURL = URL(fileURLWithPath: BeatPaths.pathForTemporaryFile(withPrefix: prefix))
                try fm.copyItem(at: documentURL, to: tempURL)
                
                try fm.replaceItem(at: backupURL, withItemAt: tempURL, backupItemName: name, resultingItemURL: nil)
                result = true
            } else {
                try fm.copyItem(at: documentURL, to: backupURL)
                result = true
            }
        } catch let error as NSError {
            print("⚠️ Backup failed", error)
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
    
    // MARK: - iCloud backup
    
    /// Mirrors a backup into the app's iCloud Drive ubiquity container. Runs off the calling thread since iCloud container resolution and file coordination can briefly block.
    @objc public class func backupToiCloud (documentURL:URL, name:String, autosave:Bool = false) {
        guard BeatBackup.iCloudAvailable else { return }
        
        DispatchQueue.global(qos: .utility).async {
            guard let iCloudFolderURL = (autosave) ? BeatBackup.iCloudAutosaveURL : BeatBackup.iCloudBackupURL else {
                // Container not reachable right now (e.g. offline) — just skip silently
                return
            }
            
            let fm = FileManager.default
            let date = documentURL.modificationDate ?? Date()
            let dateFormatter = BeatBackup.formatter
            let backupName = name + BeatBackup.separator + dateFormatter.string(from: date) + ".fountain"
            
            var backupURL = iCloudFolderURL
            backupURL.appendPathComponent(backupName)
            
            do {
                if !fm.fileExists(atPath: iCloudFolderURL.path) {
                    try fm.createDirectory(at: iCloudFolderURL, withIntermediateDirectories: true)
                }
            } catch let error as NSError {
                print("⚠️ iCloud backup folder unavailable", error)
                return
            }
            
            // Use a file coordinator for the write since this file lives in a
            // ubiquity container that the sync daemon may also be touching.
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            
            coordinator.coordinate(writingItemAt: backupURL, options: .forReplacing, error: &coordinationError) { url in
                do {
                    if fm.fileExists(atPath: url.path) {
                        try fm.removeItem(at: url)
                    }
                    try fm.copyItem(at: documentURL, to: url)
                } catch let error as NSError {
                    print("⚠️ iCloud backup failed", error)
                }
            }
            
            if let coordinationError = coordinationError {
                print("⚠️ iCloud backup coordination failed", coordinationError)
            }
            
            BeatBackup.manageBackups(url: iCloudFolderURL, autosave: autosave, iCloud: true)
        }
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
    
    fileprivate struct BeatBackupLocation {
        let url:URL
        let iCloud:Bool
        
        init(url: URL, iCloud: Bool = false) {
            self.url = url
            self.iCloud = iCloud
        }
    }
    
    /// - Parameter autosavedCopies Set `true` if this is called to get _autosaved_ (non-saved state) files and not backups (versions created when saving the document)
    /// - Parameter autosavedCopies Set `true` if this is called to get _autosaved_ (non-saved state) files and not backups (versions created when saving the document)
    /// - Parameter useiCloud Set `true` to list backups from the iCloud folder instead of the local one
    @objc public class func getBackups(autosavedCopies:Bool = false) -> Dictionary<String, Array<BeatBackupFile>>? {
        var backupFiles:[String: Array<BeatBackupFile>] = Dictionary()
        
        var locations:[BeatBackupLocation] = [BeatBackupLocation(url: (autosavedCopies) ? BeatBackup.autosaveURL : BeatBackup.backupURL) ]
        
        if BeatBackup.iCloudAvailable, BeatBackup.iCloudBackupEnabled {
            if let iCloudURL = (autosavedCopies) ? BeatBackup.iCloudAutosaveURL : BeatBackup.iCloudBackupURL {
                locations.append(BeatBackupLocation(url: iCloudURL, iCloud:true))
            }
        }
            
        for location in locations {
            do {
                let url = location.url
                let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
                
                for file in files {
                    let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                    let separatorRange = filename.range(of: BeatBackup.separator)
                    guard let separatorRange else { continue }
                    
                    let actualName = String(filename.prefix(upTo: separatorRange.lowerBound))
                    let dateStr = String(filename.suffix(from: separatorRange.upperBound))
                                        
                    let formatter = BeatBackup.formatter
                    let date = formatter.date(from: dateStr)
                    
                    if backupFiles[actualName] == nil {
                        backupFiles[actualName] = []
                    }
                    
                    // Don't allow nil values
                    guard let date, actualName.count > 0 else { continue }
                    
                    var backupURL = URL(fileURLWithPath: url.path)
                    backupURL.appendPathComponent(file)
                    
                    let backup = BeatBackupFile(name: actualName, date: date, path: backupURL.path, iCloud: location.iCloud)
                    backupFiles[actualName]?.append(backup)
                }
            } catch let error as NSError {
                print("⚠️ Can't open backup folder", error)
            }
        }
        
        return backupFiles
    }
    
    class func manageAutosaves(url:URL) {
        BeatBackup.manageBackups(url: url, autosave: true)
    }
    
    /// Manages backups. We'll keep a set number of newest backups (`self.backupCount`) on disk and remove the older ones.
    /// - Parameter url URL for the backup storage (required as this is a static func)
    /// - Parameter autosave Set `true` if this is called to do an _autosave_ (non-saved state) and not a backup (when saving a document)
    /// - Parameter useiCloud Set `true` if `url` points at the iCloud backup folder, so lookups use the matching getBackups list
    class func manageBackups(url:URL, autosave:Bool = false, iCloud:Bool = false) {
        let backupCount = (autosave) ? autosaveCopies : backupCopies
        
        let fm = FileManager.default
        guard let backups = BeatBackup.getBackups(autosavedCopies: autosave) else {
            print("No backups available, no cleanup needed.")
            return
        }
        
        for name in backups.keys {
            guard var versions = backups[name] else {
                continue
            }
            
            // Sort files and filter them based on if we're managing iCloud files or not
            versions.sort { $0.date < $1.date }
            versions = versions.filter { iCloud == $0.iCloud }
            
            if (versions.count > backupCount) {
                while (versions.count > backupCount) {
                    guard let oldVersion = versions.first, let path = oldVersion.path else { continue }
                    do {
                        versions.removeFirst()
                        try fm.removeItem(at: URL(fileURLWithPath: path))
                    } catch let error as NSError {
                        print("Error removing backup", path, error)
                    }
                }
            }
        }
    }
    
    /// Maybe this shouldn't be here?
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
