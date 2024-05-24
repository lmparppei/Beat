//
//  BeatFileImportManager.swift
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 22.5.2024.
//

import Foundation
import BeatCore

@objcMembers
public class BeatFileImportManager: NSObject {
    
    public class func importDocument(at url:URL, completion: @escaping ((URL?) -> Void)) {
        let fileName = url.lastPathComponent.replacingOccurrences(of: "." + url.pathExtension, with: "") + " (imported)"
        
        let tempURL = BeatPaths.urlForTemporaryFile(name: fileName, pathExtension: "fountain")
        
        // FDX import needs some special rules, because we are parsing XML asynchronously
        if url.pathExtension == "fdx" || url.typeIdentifier == "com.finaldraft.fdx" {
            importFDX(at: url, tempURL: tempURL) { resultURL in
                completion(resultURL)
            }
        }
        
        // TODO: Add other file format here as well
        completion(nil)
    }
    
    public class func importFDX(at url:URL, tempURL:URL, completion: @escaping ((URL?) -> Void)) {
        _ = FDXImport(url: url, importNotes: true, completion: { fdx in
            if let script = fdx?.script, script.count > 0 {
                do {
                    try fdx?.scriptAsString().write(to: tempURL, atomically: true, encoding: .utf8)
                    completion(tempURL)
                } catch {
                    completion(nil)
                }
            }
        })
    }
    
}
