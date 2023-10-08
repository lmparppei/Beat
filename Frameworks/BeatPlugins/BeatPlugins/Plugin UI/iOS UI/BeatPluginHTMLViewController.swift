//
//  BeatPluginHTMLViewController.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.7.2023.
//

import UIKit

@objc public class BeatPluginHTMLViewController:UIViewController, BeatHTMLView, WKNavigationDelegate {
    @IBOutlet @objc public var webView:BeatPluginWebView?
    public var callback: JSValue?
    public var host: BeatPlugin?
    
    public var displayed: Bool = false
    var shouldShow = false
    
    
    public required init(html: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool = false, callback: JSValue?) {
        self.webView = BeatPluginWebView.create(html: html, width: width, height: height, host: host)
        self.callback = callback
        self.host = host
        
        super.init(nibName: "BeatPluginContainerViewController", bundle: Bundle.main)
        
        if (webView != nil) {
            self.view.addSubview(webView!)
        }
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
    
    @objc public func setHTML(_ html:String) {
        webView?.setHTML(html)
    }
    
    /// Executes given string in the web view of this panel
    @objc public func runJS(_ js:String, callback:JSValue?) {
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
