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
    var additionalHeaders:String { get set }
        
    func setHTML(_ html:String)
    func runJS(_ js:String, _ callback:JSValue?)
    func closePanel(_ sender:AnyObject?)
}

@objc public protocol BeatPluginContainer:BeatHTMLView, BeatPluginContainerExports, BeatPluginContainerInstance {
    @objc var pluginName:String { get set }
    @objc var pluginOptions:[String:AnyObject] { get set }
    @objc var webView:BeatPluginWebView? { get set }
    @objc var delegate:BeatPluginDelegate? { get set }
    
#if os(iOS)
    @objc func getViewController() -> UIViewController?
#endif
    
    func containerViewDidHide()
    func load()
    func unload()
}

@objc public class BeatPluginContainerBase: UXView, BeatPluginContainer {
    @IBOutlet weak public var delegate: BeatPluginDelegate?
    
    @objc public var pluginName: String = ""
    
    public var pluginOptions: [String: AnyObject] = [:]
    public var webView: BeatPluginWebView?
    public var host: BeatPlugin?
    public var onViewWillDraw: JSValue?
    public var onViewDidHide: JSValue?
    public var additionalHeaders:String = "" {
        didSet { self.webView?.additionalHeaders = additionalHeaders }
    }
    @objc public var displayed = false

    // Callback is not used in a container, but required for conforming to protocol
    public var callback: JSValue?
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
    }
    
    public required init(html: String, headers:String, width: CGFloat, height: CGFloat, host: BeatPlugin, cancelButton: Bool, callback: JSValue?) {
        // For now, we can't create a container programmatically.
        // fatalError("init(html:etc...) has not been implemented")
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: width, height: height))
        
        self.host = host
        self.callback = callback
        //self.setup()
        self.delegate = host.delegate
        
        setup(html, headers: headers)
    }
    
    required init?(coder: NSCoder) {
        // For now, we can't create containers using coders.
        super.init(coder: coder)
    }
    
    public func setHTML(_ html: String) {
        self.webView?.setHTML(html)
    }
    
    public func runJS(_ js: String, _ callback: JSValue?) {
        self.webView?.runJS(js, callback)
    }
    
    /// We will call `setup()` directly on iOS. On macOS, it's called by `awakeFromNib`.
    @objc public func setup(_ html:String = "", headers:String = "") {
        if self.host == nil {
            self.host = BeatPlugin()
            self.host?.restorable = false
        }
        
        self.host?.delegate = self.delegate
        
        // Register this view
        self.delegate?.register(self)
        
        setupWebView(html: html, headers: headers)
    }
    
    deinit {
        unload()
    }

    /// Unloads the plugin and also removes the associated web view
    public func unload() {
        // Unload the plugin
        self.webView?.remove()
        self.host?.end()
        self.host?.container = nil
        
        // Remove
        self.onViewWillDraw = nil
        self.onViewDidHide = nil
        self.host = nil
        self.webView = nil
    }
    
    #if os(iOS)
    @objc public func getViewController() -> UIViewController? {
        var responder:UIResponder? = self.next
        while responder != nil {
            if responder!.isKind(of: UIViewController.self) {
                return responder as? UIViewController
            }
            responder = responder?.next
        }
        
        return nil
    }
    #endif
    
    /// Adds web view to the container
    func setupWebView(html:String, headers:String) {
        // Don't do this twice (can happen on iOS when the view controller is already created)
        if self.webView != nil { return }

        guard let host = self.host else {
            print("No host for container view set: ", self)
            return
        }
        
        self.webView = BeatPluginWebView.create(html: ["content": html, "headers": headers], width: self.frame.width, height: self.frame.height, host: host)
        #if os(iOS)
        self.webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #endif
        
        self.webView?.setHTML(html)
        self.host?.container = self
        
        self.addSubview(self.webView!)
    }
    
    override public func awakeFromNib() {
        setup()
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
        self.displayed = false
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
    @IBOutlet weak var viewController:UIViewController?
    
    override public func closePanel(_ sender: AnyObject?) {
        if (viewController?.navigationController != nil) {
            // We came in through a segue and need to pop this view.
            viewController?.navigationController?.popViewController(animated: true)
            unload()
        } else {
            // The VC was instantiated some other way, let's just dismiss it.
            viewController?.dismiss(animated: true)
            self.displayed = false
        }
    }
    
    /*
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        displayed = true
        onViewWillDraw?.call(withArguments: [self])
    }
     */
}

@objc public class BeatPluginContainerViewController:UIViewController {
    @IBOutlet @objc public weak var container:BeatPluginContainerView?
    @objc public weak var delegate:BeatPluginDelegate?
    @IBInspectable @objc public var pluginName:String = ""
            
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the container
        container?.pluginName = pluginName
        container?.delegate = delegate
        
        container?.setup()
        container?.load()
        
        container?.displayed = true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        container?.displayed = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        container?.displayed = false
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        sequence(first: self) { $0.next }
            .first(where: { $0 is UIViewController })
            .flatMap { $0 as? UIViewController }
    }
}

#endif
