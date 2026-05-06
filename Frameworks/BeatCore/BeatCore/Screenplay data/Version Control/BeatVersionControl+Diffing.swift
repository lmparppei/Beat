//
//  BeatVersionControl+Diffing.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 18.4.2026.
//

public extension BeatVersionControl {
    
    @objc class func diffedText(originalText:String, modifiedText:String) -> NSAttributedString? {
        guard let diffs = BeatVersionControl.compare(originalText: originalText, modifiedText: modifiedText) else { return nil }
        
        return BeatVersionControl.formatDiffedText(diffs, isOriginal: false)
    }
    
    @objc class func compare(originalText:String, modifiedText:String) -> [Diff]? {
        
        let dmp = DiffMatchPatch()
        guard let diffs = dmp.diff_main(ofOldString: originalText, andNewString: modifiedText) else { return nil }
        
        dmp.diff_cleanupSemantic(diffs)
        
        // Convert NSMutableArray to [Diff]
        var diffValues: [Diff] = []
        for d in diffs {
            if let diff = d as? Diff {
                diffValues.append(diff)
            }
        }
        
        return diffValues
    }
    
}
