//
//  BeatPluginPrint.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 28.7.2023.
//
/*
 
 Work in progress for a modern printing interface for plugins (discarding the legacy WebView)
 
 */

#if os(macOS)
import AppKit
#else
import Cocoa
#endif

#if os(macOS)

class BeatPluginPrintView:NSView, WKNavigationDelegate {
    var html:String = ""
    var printInfo:NSPrintInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
    var imageableBounds:NSRect {
        return NSPrintInfo.shared.imageablePageBounds
    }
    
    var webView:WKWebView = WKWebView(frame: NSMakeRect(0, 0, 0, 0))
    var margins:[CGFloat] = [5.0, 5.0, 5.0, 5.0] {
        didSet{
            if (margins.count < 4) {
                for _ in margins.count...4 {
                    margins.append(5.0)
                }
            }
            self.printInfo.topMargin = margins[0]
            self.printInfo.rightMargin = margins[1]
            self.printInfo.bottomMargin = margins[2]
            self.printInfo.leftMargin = margins[3]
        }
    }
    
    var waitingToPrint = false
    var readyToPrint = false
    
    // 0 is portrait, 1 landscape
    var orientation = 0 {
        didSet {
            if (orientation == 0) {
                printInfo.orientation = .portrait
            } else {
                printInfo.orientation = .landscape
            }
        }
    }

    // This is here for pre-11.0 support. Why am I doing this to myself?
    var webPrinter = BeatHTMLPrinter(name: "Beat plugin printing operation")


    init(html:String) {
        self.html = html
        super.init(frame: CGRectZero)
        
        webView.frame = CGRectMake(0, 0, self.printInfo.paperSize.width, self.printInfo.paperSize.height)
        webView.navigationDelegate = self
        self.addSubview(webView)
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        readyToPrint = true
        if (waitingToPrint) {
            runPrintOperation()
        }
    }
    
    func print() {
        if (readyToPrint) {
            runPrintOperation()
        } else {
            waitingToPrint = true
        }
    }
    
    func runPrintOperation() {
        if #available(macOS 11.0, *) {
            let operation = self.webView.printOperation(with: self.printInfo)
            operation.run()
        } else {
            // Fallback on earlier versions
        }
        
    }
}

#else

class BeatPluginPrint:NSObject {
    
}

#endif
