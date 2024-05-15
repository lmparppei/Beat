//
//  BeatPluginWindowManager.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 13.5.2024.
//
/**
 
 This is a very early idea for plugin window management. Basically we should catch minimize/show/hide events and handle the windows in our own way.
 A non-visible view would be shown as a round icon on the left-hand side of your editor view.
 
 The manager should be compatible with both macOS and iOS.
 
 */

import Foundation
import UXKit

fileprivate struct BeatPluginWindowHiddenIcon {
    var view:BeatHTMLView?
}

@objcMembers
class BeatPluginWindowManager:NSObject {
    
    var windows:[BeatHTMLView] = []
    var hiddenIconContainer:UXView?
    fileprivate var hiddenIcons:[BeatPluginWindowHiddenIcon] = []
    
    deinit {
        if let container = hiddenIconContainer {
            container.subviews.forEach { $0.removeFromSuperview() }
        }
        hiddenIconContainer = nil
        
        windows = []
    }
    
    func registerPluginView(_ view:BeatHTMLView) {
        windows.append(view)
    }
    
    func unregisterPluginView(_ view:BeatHTMLView) {
        if let i = windows.firstIndex(where: { item in return (item === view) }) {
            windows.remove(at: i)
        }
    }
    
    func minimize(_ view:BeatHTMLView) {
        view.hide?()
        update()
    }
    
    func show(_ view:BeatHTMLView) {
        // Somehow show the view
        update()
    }
    
    func update() {
        var hidden:[BeatHTMLView] = []
        
        for window in windows {
            if !window.displayed {
                hidden.append(window)
            }
        }
    }
}
