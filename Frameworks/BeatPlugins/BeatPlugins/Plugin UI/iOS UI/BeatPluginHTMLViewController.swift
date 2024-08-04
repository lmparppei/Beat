//
//  BeatPluginHTMLViewController.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.7.2023.
//

import UIKit

@objc public class BeatPluginHTMLViewController:UIViewController, BeatHTMLView, BeatPluginWebViewExports, WKNavigationDelegate {
    @IBOutlet @objc public var webView:BeatPluginWebView?
    public var callback: JSValue?
    public var host: BeatPlugin?
    public var displayed: Bool = false
    
    public var name:String? {
        return host?.pluginName
    }
    
    var shouldShow = false
    
    public required init(html: String, headers: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool = false, callback: JSValue?) {
        self.callback = callback
        self.host = host
                
        super.init(nibName: nil, bundle: nil)
        
        let content = ["content": html, "headers": headers]
        self.webView = BeatPluginWebView.create(html: content, width: self.view.frame.width, height: self.view.frame.height, host: host)
        self.webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let webView = self.webView {
            self.view.addSubview(webView)
        }
        
        self.modalPresentationStyle = .pageSheet
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func dismissView(sender: Any?) {
        self.webView?.remove()
        self.dismiss(animated: true)
    }
    
    public func closePanel(_ sender: AnyObject?) {
        self.dismissView(sender: sender)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
    }
    
    @objc public func setFrame(_ rect:CGRect) {
        // No frame setting on iOS
    }
    
    @objc public func setHTML(_ html:String) {
        webView?.setHTML(html)
    }
    
    /// Executes given string in the web view of this panel
    @objc public func runJS(_ js:String, _ callback:JSValue?) {
        self.webView?.runJS(js, callback)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        displayed = true
    }
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        displayed = false
    }
}
