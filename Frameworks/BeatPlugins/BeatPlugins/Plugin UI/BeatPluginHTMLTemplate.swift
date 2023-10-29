//
//  BeatPluginHTMLTemplate.swift
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 29.10.2023.
//

import Foundation

class BeatPluginHTMLTemplate:NSObject {
    class func html(content html:String) -> String {
        // Load template

        let bundle = Bundle(for: Self.self)
        guard let templateURL = bundle.url(forResource: "Plugin HTML template", withExtension: "html"),
              let polyfillURL = bundle.url(forResource: "Plugin polyfill", withExtension: "js"),
              let polyfill = try? String(contentsOf: polyfillURL, encoding: .utf8),
              let fontURL = Bundle.main.url(forResource: "Courier Prime", withExtension: "ttf")?.deletingLastPathComponent().path,
              var template = try? String(contentsOf: templateURL, encoding: .utf8)
        else {
            fatalError("Failed to load HTML template content!")
        }
                
        // Add the HTML to template and load the HTML in web view
        template = template.replacingOccurrences(of: "{{font-url}}", with: fontURL)
        template = template.replacingOccurrences(of: "{{polyfill}}", with: polyfill)
        template = template.replacingOccurrences(of: "<!-- CONTENT -->", with: html)
        
        return template
    }
}

/*
 
 thankful that you're showing me
 who I am and what I can do
 i don't know what I would be
 if it wasn't for girls like you
 
 */
