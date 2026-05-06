//
//  BeatVersionControl+ContinuousDiff.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 18.4.2026.
//

fileprivate var originalText:String?
fileprivate var diffTimer:Timer?

public extension BeatVersionControl {

    @objc func loadDiffForEditor(timestamp:String) {
        originalText = self.text(at: timestamp)
    }
    
    
    
}
