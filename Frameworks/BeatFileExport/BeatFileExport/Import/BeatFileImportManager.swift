//
//  BeatFileImportManager.swift
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 22.5.2024.
//

import Foundation
import BeatCore

/**
 
 This is a generic import class and it should be possible to extend this to support any sort of import modules as long as they conform to `BeatFileImportModule` protocol.
 Add module classes to `modules` array. For now, this is used only on iOS.
 
 */
@objcMembers
public class BeatFileImportManager: NSObject {
    let modules:[BeatFileImportModule.Type] = [FDXImport.self, FadeInImport.self]

    
    public var _error:Error?
    private var retainedModule:Any?
    private var waiting = false
    
    /// Main import method
    public func importDocument(at url:URL, completion: @escaping ((URL?) -> Void)) {
        waiting = false
                
        guard url.startAccessingSecurityScopedResource() else {
            completion(nil)
            return
        }
        
        // Get module for importing this format. This returns a CLASS which needs to be initialized after that.
        guard let moduleClass = importModule(for: url.pathExtension, UTI: url.typeIdentifier) else {
            print("No module for format")
            completion(nil)
            return
        }
        
        // Resulting file name
        let fileName = url.lastPathComponent.replacingOccurrences(of: "." + url.pathExtension, with: "") + " (imported)"
        let tempURL = BeatPaths.urlForTemporaryFile(name: fileName, pathExtension: "fountain")
        
        if moduleClass.asynchronous?() ?? false {
            // Asynchronous import
            waiting = true

            // Init module
            self.retainedModule = moduleClass.init(url: url) { fountain in
                if let fountain {
                    self.createImportedFile(content: fountain, url: tempURL) { url in
                        completion(url)
                        return
                    }
                } else {
                    completion(nil)
                    return
                }
            }
        } else {
            // Synchronous import
            let importModule = moduleClass.init(url: url)
            if let fountain = importModule.fountain {
                self.createImportedFile(content: fountain, url: tempURL) { url in
                    completion(url)
                }
            } else {
                completion(nil)
                return
            }
        }

        // If we're still waiting for the file, let's call the completion with nil argument ... uh.
        // Yeah, we need better error handling here, but that's a task for future me.
        if !waiting { completion(nil) }
    }
    
    /// Writes the file to a temporary directory and provides the temp URL for further handling
    private func createImportedFile(content:String, url:URL, completion: @escaping ((URL?) -> Void)) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            completion(url)
        } catch {
            _error = error
            completion(nil)
        }
    }
    
    /// Returns the import module class for given UTI / file extension
    private func importModule(for format: String, UTI: String?) -> BeatFileImportModule.Type? {
        return modules.first {
            $0.formats().contains(format) ||
            (UTI.map { $0 } != nil && $0.utis()?.contains(UTI!) == true)
        }
    }
    
}
