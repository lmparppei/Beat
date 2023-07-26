//
//  BeatPluginHTMLViewController.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.7.2023.
//

import UIKit

@objc public class BeatPluginHTMLViewController:UIViewController, BeatHTMLView, WKNavigationDelegate {
    @objc var webView:BeatPluginWebView
    var shouldShow = false
    
    public required init(html: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool = false, callback: JSValue = nil) {
        self.webView = BeatPluginWebView.create(html: html, width: width, height: height, host: host)
        self.callback = callback
        self.host = host
        
        super.init()
        
        self.view.addSubview(webView)
    }
    
    @IBAction func dismissView(sender: Any?) {
        self.webView.remove()
        self.dismiss(animated: true)
    }
    
    public func closePanel(_ sender: AnyObject?) {
        self.dismissView(sender: sender)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished navigation")
    }
    
    @objc public func setHTML(_ html:String) {
        webView.setHTML(html)
    }
    
    /// Executes given string in the web view of this panel
    @objc public func runJS(_ js:String, callback:JSValue?) {
        if (callback != nil && !callback!.isUndefined) {
            self.webView.evaluateJavaScript(js) { data, error in
                DispatchQueue.main.async {
                    let arguments = (data != nil) ? [data!] : []
                    callback?.call(withArguments: arguments)
                }
            }
        } else {
            self.webView.evaluateJavaScript(js)
        }
    }
}
