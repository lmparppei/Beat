//
//  BeatStringExtensions.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.10.2023.
//

import Foundation

extension StringProtocol {
    // Thank you, Leo Dabus @ stackoverflow
    subscript(_ offset: Int)                     -> Element     { self[index(startIndex, offsetBy: offset)] }
}
