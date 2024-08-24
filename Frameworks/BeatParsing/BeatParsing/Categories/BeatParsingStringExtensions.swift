//
//  BeatStringExtensions.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.10.2023.
//

import Foundation

extension StringProtocol {
    // Thank you, Leo Dabus @ stackoverflow
    subscript(_ offset: Int) -> Element? {
        guard offset >= 0, let index = self.index(startIndex, offsetBy: offset, limitedBy: endIndex) else {
            return nil
        }
        return self[index]
    }
}


