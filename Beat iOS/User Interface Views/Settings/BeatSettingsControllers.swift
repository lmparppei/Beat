//
//  BeatQuickSettings.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatThemes

extension BeatDocumentViewController:UIPopoverPresentationControllerDelegate {
	@IBAction func openSettings(_ sender:AnyObject?) {
		let storyboard = UIStoryboard(name: "SettingViews", bundle: .main)
		if let vc = storyboard.instantiateViewController(withIdentifier: "Settings") as? BeatSettingsViewController {
			vc.modalPresentationStyle = .formSheet
			vc.delegate = self
			self.present(vc, animated: true)
		}
	}
	
	@IBAction func openQuickSettings(_ sender: AnyObject) {
		var frame = CGRectZero
		var buttonFrame = CGRectZero
		
		if let view = sender.value(forKey: "view") as? UIView {
			frame = view.frame
			frame.origin.x += view.superview?.frame.origin.x ?? 0
			frame.origin.y -= 40.0
			buttonFrame = frame
		}
		
		//Configure the presentation controller
		let storyboard = UIStoryboard(name: "SettingViews", bundle: .main)
		let popoverContentController = storyboard.instantiateViewController(withIdentifier: "QuickSettings") as? BeatSettingsViewController
		popoverContentController?.modalPresentationStyle = .popover
		popoverContentController?.delegate = self
		
		if #available(iOS 26.0, *) {
			buttonFrame.origin.x = self.view.frame.width - 10.0
		}
		
		// Present popover
		if let popoverPresentationController = popoverContentController?.popoverPresentationController {
			popoverPresentationController.permittedArrowDirections = .up
			popoverPresentationController.sourceView = self.view
			popoverPresentationController.sourceRect = buttonFrame
			popoverPresentationController.delegate = self
			
			if let popoverController = popoverContentController {
				present(popoverController, animated: true, completion: nil)
			}
		}
	}
	
	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
	
	public func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		
	}
	
	public func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
		return true
	}
}

class BeatSettingsViewController:UITableViewController {
	@objc weak var delegate:BeatEditorDelegate?
	
	// Local document settings
	@IBOutlet weak var revisionSelector:BeatRevisionSelector?
	@IBOutlet weak var revisionMode:UISwitch?
	@IBOutlet weak var pageSizeSwitch:UISegmentedControl?
	@IBOutlet weak var headingSpacingSwitch:UISegmentedControl?
	@IBOutlet weak var lineHeightSwitch:UISegmentedControl?
	@IBOutlet weak var darkModeSwitch:UISegmentedControl?
	@IBOutlet weak var stylesheetSwitch:BeatSegmentedStylesheetControl?
	@IBOutlet weak var highContrastSwitch:UISwitch?
	
	@IBOutlet weak var sectionFontType:UIButton?
	@IBOutlet weak var sectionFontSize:UIButton?
	@IBOutlet weak var synopsisFontType:UIButton?
	
	@IBOutlet weak var fontStyleButton:UIButton?

	/// Font size switch is only available on iPhone
	@IBOutlet var fontSizeSwitch:UISegmentedControl?

	private var activeFontSettingKey:String?
	private var activeFontRequiresMonospaced = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView.delegate = self
		
		guard let delegate = self.delegate else { return }
		
		self.revisionMode?.setOn(delegate.revisionMode, animated: false)
		self.pageSizeSwitch?.selectedSegmentIndex = delegate.pageSize.rawValue
		
		let spacing = BeatUserDefaults.shared().getInteger(BeatSettingSceneHeadingSpacing)
		self.headingSpacingSwitch?.selectedSegmentIndex = (spacing == 2) ? 0 : 1
		
		let lineSpacing = delegate.documentSettings.getFloat(DocSettingNovelLineHeightMultiplier)
		self.lineHeightSwitch?.selectedSegmentIndex = (lineSpacing < 2) ? 1 : 0
		
		self.revisionSelector?.revisionLevel = delegate.revisionLevel
		self.revisionSelector?.settingController = self
		
		let highContrast = UserDefaults.standard.string(forKey: ThemeManager.loadedThemeKey()) ?? ""
		self.highContrastSwitch?.setOn(highContrast.count > 0 , animated: false)
		
		let style = BeatUserDefaults.shared().getInteger(BeatSettingFontStyle)
		if let fontStyleMenu = fontStyleButton?.menu, style < fontStyleMenu.children.count {
			(fontStyleMenu.children[style] as? UICommand)?.state = .on
		}

		self.migrateLegacyCustomFonts()
		self.setupCustomFontMenu()
		
		if let stylesheet = self.delegate?.styles.name,
		   let availableStyles = stylesheetSwitch?.stylesheets.split(separator: ",") {
			for i in 0..<availableStyles.count {
				let style = availableStyles[i]
				if String(style).lowercased() == stylesheet.lowercased() {
					stylesheetSwitch?.selectedSegmentIndex = i
				}
			}
		}
		
		if let appDelegate = UIApplication.shared.delegate as? BeatiOSAppDelegate {
			self.darkModeSwitch?.selectedSegmentIndex = appDelegate.isDark() ? 1 : 0
		}
				
		if let sectionFontType = BeatUserDefaults.shared().get(BeatSettingSectionFontType) {
			let command = self.sectionFontType?.menu?.command(withPropertyList: sectionFontType)
			command?.state = .on
		}
		
		let sectionFontSize = BeatUserDefaults.shared().getFloat(BeatSettingSectionFontSize)
		let value = String(floor(sectionFontSize))
		if let sectionFontCommand = self.sectionFontSize?.menu?.command(withPropertyList: value) {
			sectionFontCommand.state = .on
		}
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	@IBAction func toggleDarkMode(_ sender:UISegmentedControl) {
		if let appDelegate = UIApplication.shared.delegate as? BeatiOSAppDelegate {
			appDelegate.toggleDarkMode()
		}
	}
	
	@IBAction func toggleSectionFontType(_ sender:UICommand?) {
		guard let value = sender?.propertyList as? String else { return }
		if value == "system" {
			BeatUserDefaults.shared().reset(toDefault: BeatSettingSectionFontType)
		} else {
			BeatUserDefaults.shared().save(value, forKey: BeatSettingSectionFontType)
		}
		
		delegate?.reloadStyles()
		delegate?.resetPreview()
		delegate?.formatting.formatAllLines(of: .section)
	}
	
	@IBAction func toggleSynopsisFontType(_ sender:UICommand?) {
		guard let value = sender?.propertyList as? String else { return }
		if value == "system" || value == "" {
			BeatUserDefaults.shared().reset(toDefault: BeatSettingSynopsisFontType)
		} else {
			BeatUserDefaults.shared().save(value, forKey: BeatSettingSynopsisFontType)
		}
		
		delegate?.reloadStyles()
		delegate?.resetPreview()
		delegate?.formatting.formatAllLines(of: .synopse)
	}
	
	@IBAction func toggleSectionFontSize(_ sender:UICommand?) {
		guard let value = sender?.propertyList as? String else { print("!!! faulty value"); return }
		BeatUserDefaults.shared().save(value, forKey: BeatSettingSectionFontSize)
		
		delegate?.reloadStyles()
		delegate?.resetPreview()
		delegate?.formatting.formatAllLines(of: .section)
	}
	
	@IBAction func toggleSetting(_ sender:BeatUserSettingSwitch?) {
		guard let key = sender?.setting,
			  let button = sender
		else { return }
		
		if !button.documentSetting {
			BeatUserDefaults.shared().save(button.isOn, forKey: key)
		} else {
			delegate?.documentSettings.setBool(key, as: button.isOn)
		}
		
		if button.redrawTextView {
			delegate?.getTextView().setNeedsDisplay()
		}
		
		if button.reformatHeadings {
			delegate?.reloadStyles()
			delegate?.formatting.formatAllLines(of: .heading)
		}
		
		if button.resetPreview {
			delegate?.invalidatePreview()
		}
		
		if button.reloadOutline {
			// ?
		}
	}
		
	@IBAction func toggleStylesheet(_ sender:BeatSegmentedStylesheetControl) {
		let styles = sender.stylesheets.split(separator: ",")
		let stylesheetName = String(styles[sender.selectedSegmentIndex])
		self.delegate?.setStylesheetAndReformat(stylesheetName)
	}
	
	@IBAction func toggleLineSpacing(_ sender:BeatUserSettingSegmentedControl) {
		guard let setting = sender.setting else { return }

		if sender.documentSetting {
			let value = (sender.selectedSegmentIndex == 0) ? 2 : 1.5
			self.delegate?.documentSettings.set(setting, as:value)
		}
		
		self.delegate?.reloadStyles()
	}
	
	@IBAction func togglePageSize(_ sender:UISegmentedControl) {
		/// OK lol, this is a silly thing to do, but `BeatPageSize` is an enum (`0` is A4 and `1` is US Letter) so why not.
		delegate?.pageSize = BeatPaperSize(rawValue: sender.selectedSegmentIndex) ?? .A4
	}
	
	@IBAction func selectRevisionGeneration(_ sender:BeatRevisionSelector) {
		delegate?.revisionLevel = sender.revisionLevel
	}
	
	@IBAction func toggleHeadingSpacing(_ sender:UISegmentedControl) {
		let value = (sender.selectedSegmentIndex == 0) ? 2 : 1
		BeatUserDefaults.shared().save(value, forKey: BeatSettingSceneHeadingSpacing)
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		// Hide certain cells
		let cell = self.tableView(tableView, cellForRowAt: indexPath)
		
		if let cell = cell as? BeatAdaptiveCellView {
			// Adapt to device
			if cell.hiddenOnMobile && UIDevice.current.userInterfaceIdiom == .phone { return 0.0 }
			else if cell.hiddenOnPad && UIDevice.current.userInterfaceIdiom == .pad { return 0.0 }
		} else if let cell = cell as? BeatStylesheetAdaptiveCellView {
			// Adapt to stylesheet
			if cell.stylesheet != delegate?.styles.name ?? "" { return 0.0 }
		}
		
		
		return super.tableView(tableView, heightForRowAt: indexPath)
	}
	
	@IBAction func visitSite(_ sender:BeatURLButton?) {
		if let url = URL(string: sender?.url ?? "") {
			UIApplication.shared.open(url)
		}
	}
	
	@IBAction func resetSuppressedAlerts(_ sender:Any?) {
		BeatUserDefaults.shared().reset(toDefault: BeatSettingSuppressedAlert)
	}
	
	@IBAction func toggleFontSize(_ sender:BeatUserSettingSegmentedControl) {
		guard let key = sender.setting else { return }
		
		let size = sender.selectedSegmentIndex
		BeatUserDefaults.shared().save(size, forKey: key)
		
		guard let textView = self.delegate?.getTextView() as? BeatUITextView else { return }
		textView.updateMobileScale()
	}
	
	@IBAction func toggleColouredRevisionText(_ sender:BeatUserSettingSwitch) {
		self.toggleSetting(sender)
		self.delegate?.formatting.refreshRevisionTextColors()
	}
	
	@IBAction func toggleHighContrast(_ sender:UISwitch?) {
		guard let sender else { return }
		
		if sender.isOn {
			UserDefaults.standard.set("High Contrast", forKey: ThemeManager.loadedThemeKey())
		} else {
			UserDefaults.standard.removeObject(forKey: ThemeManager.loadedThemeKey())
		}
		
		ThemeManager.shared().reloadTheme()
		self.delegate?.updateUIColors()
		self.delegate?.formatting.formatAllLines()
	}
	
	@IBAction func toggleFontStyle(_ sender:UIMenuElement) {
		// This is a little hacky. 0 = serif, 1 = sans serif, 2 = courier new
		// BeatUserDefaults.shared().save(sender.selectedSegmentIndex, forKey: BeatSettingFontStyle)
		let style = if sender.title == "Courier Prime" { 0 }
					else if sender.title == "Courier Prime Sans" { 1 }
					else { 2 }
		
		// This is a little hacky. 0 = serif, 1 = sans serif, 2 = courier new
		BeatUserDefaults.shared().save(style, forKey: BeatSettingFontStyle)
		BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayFont)
		BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayEditorFont)
		BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayExportFont)
		BeatUserDefaults.shared().save("", forKey: BeatSettingCustomEditorFont)
		BeatUserDefaults.shared().save("", forKey: BeatSettingCustomExportFont)
		print("New font style:", style)


		self.applyFontChange()
	}

	// MARK: Custom fonts

	private func setupCustomFontMenu() {
		guard let button = fontStyleButton else { return }
		let existing = button.menu?.children ?? []

		let screenplayCustomAction = UIAction(title: NSLocalizedString("settings.customScreenplayFont", comment: "")) { [weak self] _ in
			self?.presentFontPicker(for: BeatSettingCustomScreenplayFont, requiresMonospaced: true)
		}
		let screenplayDefaultAction = UIAction(title: NSLocalizedString("settings.useDefaultScreenplayFont", comment: "")) { [weak self] _ in
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayExportFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomExportFont)
			self?.applyFontChange()
		}
		let novelCustomAction = UIAction(title: NSLocalizedString("settings.customNovelFont", comment: "")) { [weak self] _ in
			self?.presentFontPicker(for: BeatSettingCustomNovelFont, requiresMonospaced: false)
		}
		let novelDefaultAction = UIAction(title: NSLocalizedString("settings.useDefaultNovelFont", comment: "")) { [weak self] _ in
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelExportFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomExportFont)
			self?.applyFontChange()
		}
		let resetAction = UIAction(title: NSLocalizedString("settings.useDefaultFonts", comment: "")) { [weak self] _ in
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomExportFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomScreenplayExportFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelEditorFont)
			BeatUserDefaults.shared().save("", forKey: BeatSettingCustomNovelExportFont)
			self?.applyFontChange()
		}

		let screenplayMenu = UIMenu(title: NSLocalizedString("settings.screenplayFonts", comment: ""),
									options: .displayInline,
									children: [screenplayCustomAction, screenplayDefaultAction])
		let novelMenu = UIMenu(title: NSLocalizedString("settings.novelFonts", comment: ""),
							   options: .displayInline,
							   children: [novelCustomAction, novelDefaultAction])
		let resetMenu = UIMenu(title: "", options: .displayInline, children: [resetAction])
		button.menu = UIMenu(children: existing + [screenplayMenu, novelMenu, resetMenu])
	}

	private func migrateLegacyCustomFonts() {
		let defaults = BeatUserDefaults.shared()
		var screenplayFont = defaults.get(BeatSettingCustomScreenplayFont) as? String ?? ""
		var novelFont = defaults.get(BeatSettingCustomNovelFont) as? String ?? ""

		if let editorFont = defaults.get(BeatSettingCustomEditorFont) as? String,
		   !editorFont.isEmpty,
		   screenplayFont.isEmpty,
		   novelFont.isEmpty {
			defaults.save(editorFont, forKey: BeatSettingCustomScreenplayFont)
			defaults.save(editorFont, forKey: BeatSettingCustomNovelFont)
			screenplayFont = editorFont
			novelFont = editorFont
		}

		if let exportFont = defaults.get(BeatSettingCustomExportFont) as? String,
		   !exportFont.isEmpty,
		   screenplayFont.isEmpty,
		   novelFont.isEmpty {
			defaults.save(exportFont, forKey: BeatSettingCustomScreenplayFont)
			defaults.save(exportFont, forKey: BeatSettingCustomNovelFont)
		}

		if screenplayFont.isEmpty,
		   let legacyScreenplayFont = defaults.get(BeatSettingCustomScreenplayEditorFont) as? String,
		   !legacyScreenplayFont.isEmpty {
			defaults.save(legacyScreenplayFont, forKey: BeatSettingCustomScreenplayFont)
		}
		if novelFont.isEmpty,
		   let legacyNovelFont = defaults.get(BeatSettingCustomNovelEditorFont) as? String,
		   !legacyNovelFont.isEmpty {
			defaults.save(legacyNovelFont, forKey: BeatSettingCustomNovelFont)
		}
	}

	private func presentFontPicker(for settingKey:String, requiresMonospaced:Bool) {
		self.activeFontSettingKey = settingKey
		self.activeFontRequiresMonospaced = requiresMonospaced

		let config = UIFontPickerViewController.Configuration()
		config.includeFaces = true
		let picker = UIFontPickerViewController(configuration: config)
		picker.delegate = self
		self.present(picker, animated: true)
	}

	fileprivate func applyFontChange() {
		self.delegate?.reloadFonts()
		self.delegate?.reloadStyles()
		self.delegate?.formatting.formatAllLines()
		self.delegate?.invalidatePreview()
	}

}

extension BeatSettingsViewController:UIFontPickerViewControllerDelegate {
	func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
		viewController.dismiss(animated: true)

		guard let key = self.activeFontSettingKey,
			  let descriptor = viewController.selectedFontDescriptor
		else { return }

		let font = UIFont(descriptor: descriptor, size: 12.0)
		BeatUserDefaults.shared().save(font.fontName, forKey: key)
		self.applyFontChange()

		if self.activeFontRequiresMonospaced && !font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
			let alert = UIAlertController(title: NSLocalizedString("settings.notMonospaced.title", comment: ""),
										  message: NSLocalizedString("settings.notMonospaced.message", comment: ""),
										  preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: NSLocalizedString("general.OK", comment: ""), style: .default))
			self.present(alert, animated: true)
		}
	}

	func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
		viewController.dismiss(animated: true)
	}
}

class BeatURLButton:UIButton {
	@IBInspectable var url:String?
}

extension UIMenu {
	/// Recursively searches through a UIMenu to find a UICommand with a matching propertyList value.
	func command(withPropertyList propertyList: Any?) -> UICommand? {
		for element in self.children {
			if let command = element as? UICommand, command.propertyList as? String == propertyList as? String {
				return command
			}
			if let submenu = element as? UIMenu {
				// Recursively search in submenus
				if let foundCommand = submenu.command(withPropertyList: propertyList) {
					return foundCommand
				}
			}
		}
		return nil
	}
}

extension UIButton {
	/// Forcibly set the selected item for given button with a menu
	func forceSelectedIndex(_ index: Int) {
		guard let menu, index > 0, index < menu.children.count else {
			return
		}
		(menu.children[index] as? UIAction)?.state = .on
	}
}
