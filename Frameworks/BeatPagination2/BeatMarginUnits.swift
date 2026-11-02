//
//  BeatMarginUnits.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 2.11.2026.
//

/// - warning: This element is NOT used by the actual pagination code, just the document settings out of convenience.
public enum MarginSide: Int, CaseIterable {
    case left = 0, right, top, bottom
}

/// - warning: This element is NOT used by the actual pagination code, just the document settings out of convenience.
public enum MarginUnit: Int {
    case millimeters = 0, inches

    public static let pointsPerInch: Double = 72.0
    public static let mmPerInch: Double = 25.4

    public func fromPoints(_ pt: Double) -> Double {
        switch self {
        case .inches:      return pt / Self.pointsPerInch
        case .millimeters: return pt / Self.pointsPerInch * Self.mmPerInch
        }
    }

    public func toPoints(_ value: Double) -> Double {
        switch self {
        case .inches:      return value * Self.pointsPerInch
        case .millimeters: return value / Self.mmPerInch * Self.pointsPerInch
        }
    }

    public var fractionDigits: Int { self == .inches ? 2 : 1 }
    public var suffix: String { self == .inches ? "in" : "mm" }

    public static var localeDefault: MarginUnit {
        Locale.current.usesMetricSystem ? .millimeters : .inches
    }
}
