//
//  Document+QuickSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension Document:NSPopoverDelegate {

	@IBAction func showQuickSettings(_ sender:NSButton) {
		let settings = BeatDesktopQuickSettings()
		settings.delegate = self as? BeatQuickSettingsDelegate

		let popover = NSPopover()
		popover.contentViewController = settings
		popover.behavior = .transient
		popover.delegate = self
		self.quickSettingsPopover = popover
		
		popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
	}
	
	public func popoverWillClose(_ notification: Notification) {
		if let popover = notification.object as? NSPopover, popover == self.quickSettingsPopover {
			quickSettingsButton?.state = .off
			quickSettingsPopover = nil
		}
	}
	
	/*
	 - (IBAction)showQuickSettings:(NSButton*)sender
	 {
		 if (sender == nil) return;
		 
		 NSPopover* popover = NSPopover.new;
		 BeatDesktopQuickSettings* settings = BeatDesktopQuickSettings.new;
		 settings.delegate = self;
		 
		 popover.contentViewController = settings;
		 popover.behavior = NSPopoverBehaviorTransient;
		 [popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
		 
		 popover.delegate = self;
		 
		 _quickSettingsPopover = popover;
	 }

	 - (void)popoverWillClose:(NSNotification *)notification
	 {
		 if (notification.object == _quickSettingsPopover) {
			 _quickSettingsButton.state = NSOffState;
			 _quickSettingsPopover = nil;
		 }
	 }
	 */
	
}

extension Document {
	@IBAction func openDiffViewer(_ sender:Any?) {
		let storyboard = NSStoryboard(name: "DiffViewer", bundle: Bundle.main)
		if let windowController = storyboard.instantiateController(withIdentifier: "DiffViewWindow") as? NSWindowController {
			let diffViewer = windowController.contentViewController as? DiffViewerViewController
			diffViewer?.delegate = self
			
			if let window = windowController.window, let documentWindow {
				documentWindow.beginSheet(window) { response in
				}
			}
		}
	}
}
