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
import UXKit

//public typealias JSrunJS = (@convention(block) (String, JSValue?) -> Void)

@objc public protocol BeatPluginContainerExports:JSExport {
    var pluginName:String { get }
    var onViewWillDraw:JSValue? { get set }
    var onViewDidHide: JSValue? { get set }
    var displayed:Bool { get }

    func setHTML(_ html:String)
    func runJS(_ js:String, _ callback:JSValue?)
    func closePanel(_ sender:AnyObject?)
}

@objc public protocol BeatPluginContainer:BeatHTMLView, BeatPluginContainerExports {
    var pluginName:String { get set }
    var pluginOptions:[String:AnyObject] { get set }
    var webView:BeatPluginWebView? { get set }
    var delegate:BeatPluginDelegate? { get set }
    
    func containerViewDidHide()
    func load()
}

@objc public class BeatPluginContainerBase: UXView, BeatPluginContainer {
    @objc public var pluginName: String = ""
    @IBOutlet public var delegate: BeatPluginDelegate?
    public var pluginOptions: [String: AnyObject] = [:]
    public var webView: BeatPluginWebView?
    public var host: BeatPlugin?
    public var onViewWillDraw: JSValue?
    public var onViewDidHide: JSValue?
    @objc public var displayed = false

    // Callback is not used in a container, but required for conforming to protocol
    public var callback: JSValue?
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
    }
    
    public required init(html: String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool, callback: JSValue?) {
        // For now, we can't create a container programmatically.
        fatalError("init(html:etc...) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        // For now, we can't create containers using coders.
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setHTML(_ html: String) {
        self.webView?.setHTML(html)
    }
    
    public func runJS(_ js: String, _ callback: JSValue?) {
        self.webView?.runJS(js, callback)
    }
        
    /// Adds web view to the container
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
    
    override public func awakeFromNib() {
        self.host = BeatPlugin()
        self.host?.delegate = self.delegate
        
        // Register this view
        self.delegate?.register(self)
        
        setupWebView(html: "")
    }
    
    public func load() {
        // Let's load the plugin only when asked.
        if (self.pluginName.count > 0) {
            self.host?.load(withName: self.pluginName)
        }
    }
    
    // - MARK: OS-specific methods
    // These have to be overridden in OS-specific classes
    public func closePanel(_ sender: AnyObject?) {
        fatalError("Override closePanel in OS-specific classes")
    }

    public func containerViewDidHide() {
        onViewDidHide?.call(withArguments: [self])
    }
}

// MARK: - OS-specific implementations

#if os(macOS)

@objc public class BeatPluginContainerView:BeatPluginContainerBase {
    override public func closePanel(_ sender: AnyObject?) {
        self.delegate?.returnToEditor?()
    }
     
    public override func viewWillDraw() {
        super.viewWillDraw()
        displayed = true
        onViewWillDraw?.call(withArguments: [self])
    }
}

#elseif os(iOS)

@objc public class BeatPluginContainerView:BeatPluginContainerBase {
    override public func closePanel(_ sender: AnyObject?) {
        
    }
    
    /*
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        displayed = true
        onViewWillDraw?.call(withArguments: [self])
    }
     */
}

#endif
