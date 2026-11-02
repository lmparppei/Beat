//
//  Margins.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 2.11.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa

extension BeatDocumentSettingWindow:NSTextFieldDelegate {
	static let modifierRange: ClosedRange<Double> = -40...40   // points
	
	func setupMargins() {
		for side in MarginSide.allCases {
			let field = field(for: side)
			field.tag = side.rawValue
			field.delegate = self          // commit on Return / focus loss
			field.target = self
			field.action = #selector(marginFieldChanged(_:))
		}
		
		unitMillimetersRadio.tag = MarginUnit.millimeters.rawValue
		unitInchesRadio.tag = MarginUnit.inches.rawValue
		
		refreshUnitRadios()
		refreshAllFields()
	}

	// MARK: Actions
	@IBAction func unitChanged(_ sender: NSButton) {
		guard let newUnit = MarginUnit(rawValue: sender.tag) else { return }
		unit = newUnit
		refreshUnitRadios()
		refreshAllFields()
	}
	
	@IBAction func marginFieldChanged(_ sender: NSTextField) {
		guard let side = MarginSide(rawValue: sender.tag) else { return }
		commit(text: sender.stringValue, for: side)
		refreshField(for: side)   // always show the effective (clamped) value
	}

	// Fires on focus loss too, not just Return
	func controlTextDidEndEditing(_ obj: Notification) {
		guard let tf = obj.object as? NSTextField else { return }
		marginFieldChanged(tf)
	}

	// MARK: Core logic
	private func commit(text: String, for side: MarginSide) {
		// Accept both "12,5" and "12.5" regardless of locale
		let normalized = text.trimmingCharacters(in: .whitespaces)
		let value = formatter.number(from: normalized)?.doubleValue
			?? Double(normalized.replacingOccurrences(of: ",", with: "."))
		guard let value else { return }   // unparseable: ignore, field gets reverted

		let fullPoints = unit.toPoints(value)
		let rawModifier = fullPoints - basePoints(for: side)
		let clamped = min(max(rawModifier, Self.modifierRange.lowerBound),
						  Self.modifierRange.upperBound)
		setModifier(clamped, for: side)
	}

	private func fullPoints(for side: MarginSide) -> Double {
		basePoints(for: side) + modifier(for: side)
	}

	// MARK: Refresh
	private func refreshAllFields() {
		MarginSide.allCases.forEach(refreshField(for:))
	}

	private func refreshField(for side: MarginSide) {
		formatter.maximumFractionDigits = unit.fractionDigits
		let display = unit.fromPoints(fullPoints(for: side))
		field(for: side).stringValue = formatter.string(from: NSNumber(value: display)) ?? ""
	}

	private func refreshUnitRadios() {
		unitMillimetersRadio.state = (unit == .millimeters) ? .on : .off
		unitInchesRadio.state      = (unit == .inches)      ? .on : .off
	}

	// MARK: Mapping helpers (plug in your real sources here)
	private func field(for side: MarginSide) -> NSTextField {
		switch side {
		case .left:   return marginLeftField
		case .right:  return marginRightField
		case .top:    return marginTopField
		case .bottom: return marginBottomField
		}
	}

	private func basePoints(for side: MarginSide) -> Double {
		guard let styles = editorDelegate?.styles else { return 0 }
		switch side {
		case .left:   return styles.page().marginLeft + modifier(for: .left)
		case .right:  return styles.page().marginRight + modifier(for: .right)
		case .top:    return styles.page().marginTop + modifier(for: .top)
		case .bottom: return styles.page().marginBottom + modifier(for: .bottom)
		}
	}

	private func modifier(for side: MarginSide) -> Double {
		guard let documentSettings = editorDelegate?.documentSettings else { return 0 }
		switch side {
		case .left:   return documentSettings.getFloat(DocSettingMarginModifierLeft)
		case .right:  return documentSettings.getFloat(DocSettingMarginModifierRight)
		case .top:    return documentSettings.getFloat(DocSettingMarginModifierTop)
		case .bottom: return documentSettings.getFloat(DocSettingMarginModifierBottom)
		}
	}

	private func setModifier(_ value: Double, for side: MarginSide) {
		guard let documentSettings = editorDelegate?.documentSettings else { return }
		switch side {
		case .left:   documentSettings.setFloat(DocSettingMarginModifierLeft, as: value)
		case .right:  documentSettings.setFloat(DocSettingMarginModifierRight, as: value)
		case .top:    documentSettings.setFloat(DocSettingMarginModifierTop, as: value)
		case .bottom: documentSettings.setFloat(DocSettingMarginModifierBottom, as: value)
		}
		// TODO: trigger relayout / mark document dirty here
	}
}
