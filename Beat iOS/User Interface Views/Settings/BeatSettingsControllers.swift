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
	
	/// Font size switch is only available on iOS
	@IBOutlet var fontSizeSwitch:UISegmentedControl?
	
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
	
	@IBAction func toggleFontStyle(_ sender:UISegmentedControl) {
		let sansSerif = (sender.selectedSegmentIndex == 1)
		BeatUserDefaults.shared().save(sansSerif, forKey: BeatSettingUseSansSerif)
		
		self.delegate?.reloadStyles()
		self.delegate?.formatting.formatAllLines()
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
