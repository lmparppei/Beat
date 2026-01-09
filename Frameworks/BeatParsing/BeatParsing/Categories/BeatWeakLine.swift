//
//  BeatWeakLine.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 15.10.2025.
//

import Foundation

/**
 This is a wrapper class for represented lines in editor.  `BeatEditorFormatting` applies this as value to an attribute, and because attributes can't have weak values, we need a wrapper.
 */
@objcMembers
public class BeatWeakLine: NSObject {
    public class func withLine(_ line:Line) -> BeatWeakLine {
        return BeatWeakLine(line: line)
    }
    
    init(line: Line? = nil) {
        self.line = line
        super.init()
    }
    
    public weak var line:Line?
    
    public var position:Int {
        return line?.position ?? NSNotFound
    }
    
    public var string:String {
        return line?.string ?? ""
    }
}
