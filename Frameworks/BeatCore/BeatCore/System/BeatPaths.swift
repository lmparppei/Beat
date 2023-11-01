//
//  BeatDataPaths.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 30.10.2023.
//

import Foundation

@objc public final class BeatPaths:NSObject {
    @objc public class func appDataPath(_ subPath: String) -> URL {
        guard let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String else {
            fatalError("Unable to retrieve the app name from the bundle.")
        }
        
        var pathComponent = appName
        
        if !subPath.isEmpty {
            pathComponent = (pathComponent as NSString).appendingPathComponent(subPath)
        }
        
        let searchPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupportDir = searchPaths.first?.appendingPathComponent(pathComponent) else {
            fatalError("Unable to create the application support directory path.")
        }
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: appSupportDir.path) {
            do {
                try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Error creating the application support directory: \(error)")
            }
        }
        
        return appSupportDir
    }
    
    @objc public class func pathForTemporaryFile(withPrefix prefix: String) -> String {
        let uuid = UUID()
        let result = NSTemporaryDirectory() + "\(prefix)-\(uuid.uuidString)"
        return result
    }
}
