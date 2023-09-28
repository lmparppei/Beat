//
//  Localizable.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 27.9.2023.
//

import Foundation

protocol Localizable {
    var localized: String { get }
}
extension String: Localizable {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

protocol XIBLocalizable {
    var xibLocKey: String? { get set }
}

#if os(iOS)
import UIKit
extension UILabel: XIBLocalizable {
    @IBInspectable var xibLocKey: String? {
        get { return nil }
        set(key) {
            text = key?.localized
        }
    }
}
extension UIButton: XIBLocalizable {
    @IBInspectable var xibLocKey: String? {
        get { return nil }
        set(key) {
            setTitle(key?.localized, for: .normal)
        }
   }
}
#else
import AppKit
extension NSTextField: XIBLocalizable {
    @IBInspectable var xibLocKey: String? {
        get { return nil }
        set(key) {
            if key?.localized != nil {
                stringValue = key?.localized ?? ""
            }
        }
    }
}
extension NSButton: XIBLocalizable {
    @IBInspectable var xibLocKey: String? {
        get { return nil }
        set(key) {
            if key?.localized != nil {
                self.title = key!.localized
            }
        }
   }
}
#endif

