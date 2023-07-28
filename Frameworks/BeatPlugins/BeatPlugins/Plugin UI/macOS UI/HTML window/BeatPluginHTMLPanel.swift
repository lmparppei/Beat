//
//  BeatPluginHTMLPanel.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.7.2023.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import WebKit

@objc public class BeatPluginHTMLPanel: NSPanel, BeatHTMLView {
    @objc public var displayed: Bool = true
    @objc public var callback:JSValue?
    @objc public var webView:BeatPluginWebView?
    @objc public weak var host:BeatPlugin?
    
    @objc required public init(html: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool = false, callback:JSValue?) {
        self.callback = callback
        self.host = host
        
        var adjustedWidth = width
        var adjustedHeight = height
        
        if width <= 0 { adjustedWidth = 600 }
        if width > 800 { adjustedWidth = 1000 }
        if height <= 0 { adjustedHeight = 400 }
        if height > 800 { adjustedHeight = 1000 }
                
        let webView = BeatPluginWebView.create(html: html, width: width, height: height, host: host)
        webView.frame = NSRect(x: 0, y: 35, width: adjustedWidth, height: adjustedHeight)
        self.webView = webView
        
        super.init(contentRect: NSRect(x: 0, y: 0, width: adjustedWidth, height: adjustedHeight + 35),
                   styleMask: [.titled],
                   backing: .buffered,
                   defer: true)
                
        // Add web view
        contentView?.addSubview(webView)
        
        // Create buttons
        let okButton = NSButton(frame: NSRect(x: adjustedWidth - 90, y: 5, width: 90, height: 24))
        okButton.bezelStyle = .rounded
        okButton.setButtonType(.momentaryLight)
        
        okButton.target = self
        okButton.action = #selector(fetchHTMLPanelDataAndClose)
        
        // Make ESC close the panel
        okButton.keyEquivalent = "\u{1b}"
        okButton.title = NSLocalizedString("general.close", comment: "Close")
        contentView?.addSubview(okButton)
        
        // Add cancel button -- if needed
        if cancelButton {
            let cancelButton = NSButton(frame: NSRect(x: adjustedWidth - 175, y: 5, width: 90, height: 24))
            cancelButton.bezelStyle = .rounded
            cancelButton.setButtonType(.momentaryLight)
            cancelButton.target = self
            cancelButton.action = #selector(closePanel(_:))
            
            // Close button is now OK, and Enter is the shortcut for sending the data
            okButton.title = NSLocalizedString("general.ok", comment: "OK")
            okButton.keyEquivalent = "\r"
            
            // ESC closes the panel
            cancelButton.keyEquivalent = "\u{1b}"
            cancelButton.title = NSLocalizedString("general.cancel", comment: "Cancel")
            contentView?.addSubview(cancelButton)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
     
    /// Gets HTML data from the window (and checks if the Beat injected code is still there). The actual handling of this message is done in main plugin class, which is a bit inconvenient. The async dispatch is for forcing the panel to be closed if the plugin didn't respond in time.
    @objc func fetchHTMLPanelDataAndClose() {
        self.webView?.evaluateJavaScript("sendBeatData();")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // your code here
            guard let weakSelf = self else { return }
            if weakSelf.sheetParent?.attachedSheet == weakSelf && weakSelf.isVisible {
                weakSelf.host?.reportError("Plugin timed out", withText: "Something went wrong with receiving data from the plugin")
                weakSelf.closePanel(nil)
            }
        }
    }
    
    /// Closes the panel and removes the script handlers. Always use this when closing the panel.
    @objc public func closePanel(_ sender:AnyObject?) {
        if (host?.delegate.documentWindow.attachedSheet != nil) {
            displayed = false
            self.webView?.remove()
            host?.delegate.documentWindow.endSheet(self)
        }
    }
    
    /// Executes given string in the web view of this panel
    @objc public func runJS(_ js:String, callback:JSValue) {
        self.webView?.runJS(js, callback)
    }
}
