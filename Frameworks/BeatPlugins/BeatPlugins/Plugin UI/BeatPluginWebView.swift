//
//  BeatPluginWebView.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/**
 This class allows plugin window HTML views to be accessed with a single click.
 */

#if os(macOS)
import AppKit
#else
import UIKit
#endif
@preconcurrency import WebKit

@objc public protocol BeatPluginWebViewExports:JSExport {
    func setHTML(_ html:String)
    func runJS(_ js:String, _ callback:JSValue?)
}

/// A protocol which hsa the basic methods for interacting with both the window and its HTML content.
@objc public protocol BeatHTMLView:BeatPluginWebViewExports {
    @objc init(html: String, headers: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool, callback:JSValue?)
    @objc func closePanel(_ sender:AnyObject?)
    @objc optional func hide()
    //@objc func fetchHTMLPanelDataAndClose()
    @objc var webView:BeatPluginWebView? { get set }
    
    var displayed:Bool { get set }
    var callback:JSValue? { get set }
    weak var host:BeatPlugin? { get set }
}

@objc public class BeatPluginWebView:WKWebView, BeatPluginWebViewExports, WKNavigationDelegate, WKUIDelegate {
    @objc weak public var host:BeatPlugin?
    /// The folder URL provided by plugin host (if applicable)
    var baseURL:URL?
    /// A temporary URL for the displayed page. Can be `nil` if we're not loading a plugin.
    var tempURL:URL?
    /// Additional headers
    var additionalHeaders = ""
    
    @objc
    public class func create(html:Dictionary<String, String>, width:CGFloat, height:CGFloat, host:BeatPlugin) -> BeatPluginWebView {
        // Create configuration for WKWebView
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Message handlers
        if #available(macOS 11.0, iOS 15.0, *) {
            config.userContentController.addScriptMessageHandler(host, contentWorld: .page, name: "callAndWait")
        }

        config.userContentController.add(host, name: "sendData")
        config.userContentController.add(host, name: "call")
        config.userContentController.add(host, name: "log")
        
        if #available(macOS 12.3, iOS 15.0, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        // Initialize (custom) webkit view
        let webView = BeatPluginWebView(frame: CGRect(x: 0, y: 0, width: width, height: height), configuration: config)
        if #available(macOS 13.3, iOS 16.4, tvOS 16.4, *) {
            webView.isInspectable = true
        }
        
        #if os(macOS)
        webView.autoresizingMask = [.width, .height]
        #elseif os(iOS)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #endif
        
        let content = html["content"] ?? ""
        let headers = html["headers"] ?? ""
        
        webView.host = host
        webView.baseURL = (host.pluginURL != nil) ? host.pluginURL : nil
        webView.additionalHeaders = headers
        
        webView.setHTML(content)
        webView.navigationDelegate = webView
        
        webView.uiDelegate = webView
        
        return webView
    }
    
    
    /// On deinit, we'll remove the temporary HTML file
    deinit {
        purge()
    }
        
    @objc public func purge() {
        guard let url = self.tempURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Temporary file couldn't be removed:", error)
        }
    }
    
    /// Evaluates JavaScript in the view and runs callback
    public func runJS(_ js:String, _ callback:JSValue?) {
        self.evaluateJavaScript(js) { returnValue, error in
            if error != nil { print("Error:", error ?? ""); return }
             
            if let c = callback {
                if !c.isUndefined {
                    callback?.call(withArguments: (returnValue != nil) ? [returnValue!] : [])
                }
            }
        }
    }
    
    /// Removes the web view from superview and disables all script message handlers
    @objc public func remove() {
        self.host = nil
        
        self.configuration.userContentController.removeScriptMessageHandler(forName: "sendData")
        self.configuration.userContentController.removeScriptMessageHandler(forName: "call")
        self.configuration.userContentController.removeScriptMessageHandler(forName: "log")

        if #available(macOS 11.0, iOS 15.0, *) {
            self.configuration.userContentController.removeScriptMessageHandler(forName: "callAndWait", contentWorld: .page)
        }
        
        self.removeFromSuperview()
    }
    
    /// Sets the HTML string and loads the template, which includes Beat code injections.
    @objc public func setHTML(_ html:String) {
        // Load template
        let template = BeatPluginHTMLTemplate.html(content: html, headers: self.additionalHeaders)
        
        var loadedURL = false
        if let baseURL = self.baseURL {
            // Write a temporary file from which to load this page. Reuse the URL if possible.
            if let tempURL = (self.tempURL == nil) ? baseURL.appendingPathComponent("__beat_tmp_" + NSUUID().uuidString + ".html") : self.tempURL {
                do {
                    try template.write(to: tempURL, atomically: true, encoding: .utf8)
                    self.loadFileURL(tempURL, allowingReadAccessTo: baseURL)
                    
                    // Successfully loaded the temporary file.
                    loadedURL = true
                    self.tempURL = tempURL
                } catch {
                    print("Couldn't write temporary HTML file")
                }
            }
        }
        
        // If we couldn't load a URL, let's load the string instead
        if (!loadedURL) {
            self.loadHTMLString(template, baseURL: nil)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url,
              let scheme = url.scheme
        else {
            decisionHandler(.cancel)
            return
        }

        #if os(macOS)
        // Allow e-mails on macOS
        if scheme.lowercased() == "mailto" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        #endif
        
        decisionHandler(.allow)
    }
    
    #if os(macOS)
	override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
		let window = self.window as? BeatPluginHTMLWindow ?? nil
		
		// If the window is floating (meaning it belongs to the currently active document)
		// we'll return true, otherwise it will behave in a normal way.
		if window?.level == .floating {
			return true
		} else {
			return false
		}
	}
    #endif
    
    #if os(iOS)
    public func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping @MainActor (UIContextMenuConfiguration?) -> Void) {
        completionHandler(nil)
    }
    
    #endif
}
