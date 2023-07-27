//
//  BeatPluginContainer.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 26.7.2023.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

//public typealias JSrunJS = (@convention(block) (String, JSValue?) -> Void)

@objc public protocol BeatPluginContainerExports:JSExport {
    func setHTML(_ html:String)
    func runJS(_ js:String, _ callback:JSValue?)
    var pluginName:String { get }
    func closePanel(_ sender:AnyObject?)
}

@objc public protocol BeatPluginContainer:BeatHTMLView, BeatPluginContainerExports {
    var pluginName:String { get set }
    var pluginOptions:[String:AnyObject] { get set }
    var webView:BeatPluginWebView? { get set }
    var delegate:BeatPluginDelegate? { get set }
    func load()
}

#if os(macOS)

@objc public class BeatPluginContainerView:NSView, BeatPluginContainer, BeatPluginContainerExports {
    @IBInspectable public var pluginName:String = ""
    @IBOutlet public var delegate:BeatPluginDelegate?
    public var pluginOptions: [String : AnyObject] = [:]
    public var webView: BeatPluginWebView?
    public var host: BeatPlugin?

    public required init(html: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool, callback: JSValue) {
        fatalError("init(html:etc...) has not been implemented")
    }
    
    func setupWebView(html:String) {
        guard let host = self.host else {
            print("No host for container view set: ", self)
            return
        }
        self.webView = BeatPluginWebView.create(html: html, width: self.frame.width, height: self.frame.height, host: host)
        self.webView?.setHTML(html)
        self.host?.container = self
        
        self.addSubview(self.webView!)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    override public func awakeFromNib() {
        self.host = BeatPlugin()
        self.host?.delegate = self.delegate
        
        // Register this view
        self.delegate?.register(self)
        
        setupWebView(html: "")
    }
    
    @objc public func load() {
        // Let's load the plugin only when asked.
        if (self.pluginName.count > 0) {
            self.host?.load(withName: self.pluginName)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func closePanel(_ sender: AnyObject?) {
        self.delegate?.returnToEditor?()
        
        // This does nothing in a container view (for now)
    }
    
    public func setHTML(_ html:String) {
        self.webView?.setHTML(html)
    }

    public func runJS(_ js:String, _ callback:JSValue?) {
        self.webView?.runJS(js, callback)
    }
    
    public var callback: JSValue?
    
}

#endif
