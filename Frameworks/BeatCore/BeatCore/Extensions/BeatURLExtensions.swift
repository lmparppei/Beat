//
//  BeatURLExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 17.4.2023.
//

import Foundation

public extension URL
{
    func withSecurityScopedAccess<R>(code: (URL) throws -> R) rethrows -> R
    {
        _ = self.startAccessingSecurityScopedResource()
        defer {
            DispatchQueue.main.async {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try code(self)
    }
    
    var typeIdentifier: String? { (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier }
    
    var localizedName: String? { (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName }
}
