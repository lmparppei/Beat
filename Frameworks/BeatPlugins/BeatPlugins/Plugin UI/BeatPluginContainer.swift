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
    func unload()
}

@objc public class BeatPluginContainerBase: UXView, BeatPluginContainer {
    @objc public var pluginName: String = ""
    @IBOutlet weak public var delegate: BeatPluginDelegate?
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
        super.init(coder: coder)
    }
    
    public func setHTML(_ html: String) {
        self.webView?.setHTML(html)
    }
    
    public func runJS(_ js: String, _ callback: JSValue?) {
        self.webView?.runJS(js, callback)
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
        
    /// Adds web view to the container
    func setupWebView(html:String) {
        // Don't do this twice (can happen on iOS when the view controller is already created)
        if self.webView != nil { return }

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
        setup()
    }
    
    /// We will call `setup()` directly on iOS. On macOS, it's called by `awakeFromNib`.
    @objc public func setup() {
        if self.host == nil {
            self.host = BeatPlugin()
            self.host?.restorable = false
        }
        
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
