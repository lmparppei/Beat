//
//  BeatTextChangeObserver.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 11.6.2024.
//

import Foundation

@objc public protocol BeatTextChangeObservable {
    func notifyTextChange()
    func addTextChangeObserver(_ observer:BeatTextChangeObserver)
    func removeTextChangeObserver(_ observer:BeatTextChangeObserver)
}

@objc public protocol BeatTextChangeObserver {
    func observedTextDidChange(_ object:BeatTextChangeObservable)
}

