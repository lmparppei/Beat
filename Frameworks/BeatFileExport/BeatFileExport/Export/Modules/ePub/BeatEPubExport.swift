//
//  BeatEPubExport.swift
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 23.8.2025.
//

import Foundation
import ZIPFoundation
import BeatCore

struct BeatEPubChapter {
    var title:String
    var filename:String
    
    var html:String
    
    var manifest:String
    var navPoint:String
}

public class BeatEPubExport:NSObject {
    public class func register(_ manager:BeatFileExportManager) {
        manager.registerHandler(for: "ePub", fileTypes: ["epub"], supportedStyles: ["Novel"]) { delegate in
            let exporter = BeatEPubExporter(delegate: delegate)
            return exporter.ePubFile(delegate)
        }
    }
}

public class BeatEPubExporter:NSObject {
    var parser:ContinuousFountainParser
    var document:BeatScreenplay
    var settings:BeatExportSettings
    
    init(delegate: BeatEditorDelegate) {
        self.settings = delegate.exportSettings
        self.parser = delegate.parser
        self.document = BeatScreenplay.from(delegate.parser, settings: delegate.exportSettings)
        
        super.init()
    }
    
    var metaContainer = """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
            <rootfile full-path="OEBPS/content.opf"
                media-type="application/oebps-package+xml" />
        </rootfiles>
    </container>
    """
    
    var mimeType = "application/epub+zip"
    
    var dateTime:String {
        if #available(macOS 12.0, *) {
            return Date().ISO8601Format()
        } else {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return dateFormatter.string(from: date)
        }
    }
    
    //<itemref idref="toc" />
    
    var contentManifest = Template(template: """
    <?xml version="1.0" encoding="UTF-8" ?>
    <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" unique-identifier="db-id" version="3.0">

    <metadata>
        <meta property="dcterms:modified">{{ date }}</meta>
        <meta content="(beat)" name="generator"/>

        <dc:title>{{ title }}</dc:title>
        <dc:creator>{{ authors }}</dc:creator>
        <dc:identifier id="db-id">{{ uuid }}</dc:identifier>
        <dc:language>en</dc:language>
    </metadata>

    <manifest>
        <item id="toc" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav" />
        <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml" />
        {{ manifest }}
    </manifest>

    <spine>
        {{ spine-items }}
    </spine>

    </package>
    """)
    
    var itemRef = Template(template: "<itemref idref=\"{{id}}\" />\n")
    
    var css = """
    body { font-size: 0.85em; }

    h1, h2, h3 { text-align: center; }
    h1 { padding-top: 6em; }
    h2 { padding-top: 5em; font-weight: normal; }
    
    p { margin: 0; text-indent: 1.5em; }
    .first { margin-top: 1em; text-indent: 0; }

    .centered { text-align: center; }
    .lyrics { text-align: center; font-style: italic; }
    .heading { text-align: center; }

    """
    
    var pageTemplate = Template(template: """
    <?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <head>
        <title>{{ title }}</title>
        <style>{{ style }}</style>
    </head>
    <body>
        {{ body }}
    </body>
    </html>
    """)
    
    var titlePageTemplate = Template(template: """
    <h1>{{ title }}</h1>
    <p class='center'>{{ authors }}</p>
    """)
    
    var toc = Template(template: """
    <?xml version="1.0" encoding="utf-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <head>
    <title>Table of Contents</title>
    </head>
    <body>
     <nav id="toc" epub:type="toc">
         <ol>
            {{ toc-items }}
         </ol>
     </nav>
    </body>
    </html>
    """)
    var tocLink = Template(template: "<li><a href='{{fileName}}.xhtml'>{{title}}</a></li>")
    
    var tocNCX = Template(template: """
     <?xml version="1.0" encoding="UTF-8" ?>
     <ncx version="2005-1" xml:lang="en" xmlns="http://www.daisy.org/z3986/2005/ncx/">

     <head>
         <meta content="isbn" name="dtb:uid"/>
     </head>

     <docTitle>
         <text>{{ title }}</text>
     </docTitle>

     <navMap>
        {{ navPoints }}
     </navMap>

     </ncx>
    """)
    
    var manifestItem = Template(template: """
      <item id="{{ filename }}" href="{{ filename }}.xhtml" media-type="application/xhtml+xml" />
    """)
    
    var navPoint = Template(template: """
        <navPoint id="{{ id }}" playOrder="{{ order }}">
            <navLabel><text>{{ title }}</text></navLabel>
            <content src="{{ source }}.xhtml" />
        </navPoint>
    """)
    
    func ePubFile(_ delegate:BeatEditorDelegate) -> Data? {
        let ePubPath = NSTemporaryDirectory() + "/ePubTemp/"
        let url = URL(fileURLWithPath: ePubPath)
        
        let zipUrl = URL(fileURLWithPath: BeatPaths.pathForTemporaryFile(withPrefix: "epub"))
        
        guard let archive = try? Archive(url: zipUrl, accessMode: .create, pathEncoding: .utf8) else {
            print("Can't create ePub archive")
            return nil
        }
        
        let chapterData = chapterFiles()
    
        let metaPath = ePubPath + "META-INF/"
        let OEBPSPath = ePubPath + "OEBPS/"
        let CSSPath = ePubPath + "CSS/"
        
        var oneLineTitle = self.document.titlePageText(forField: "title").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if oneLineTitle.count == 0 { oneLineTitle = "---" }
        
        let authors = self.document.titlePageText(forField: "authors").replacingOccurrences(of: "\n", with: ", ").trimmingCharacters(in: .whitespaces)
        
        try? FileManager.default.createDirectory(atPath: ePubPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: metaPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: OEBPSPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: CSSPath, withIntermediateDirectories: true)
        
        // Create mime type file
        let mimeTypeURL = URL(fileURLWithPath: BeatPaths.pathForTemporaryFile(withPrefix: ""))
        try? mimeType.write(to: mimeTypeURL, atomically: true, encoding: .utf8)
        try? archive.addEntry(with: "mimetype", fileURL: mimeTypeURL , compressionMethod: .none)
        
        // Create container XML
        let containerURL = URL(fileURLWithPath: metaPath + "container.xml")
        try? metaContainer.write(to: containerURL, atomically: true, encoding: .utf8)
        try? archive.addEntry(with: "META-INF/" + containerURL.lastPathComponent, relativeTo: url, compressionMethod: .none)

        // Create OEBPS files
        for chapter in chapterData {
            let fileName = chapter.filename + ".xhtml"
            let chapterURL = URL(fileURLWithPath: OEBPSPath + fileName)
            try? chapter.html.write(to: chapterURL, atomically: true, encoding: .utf8)
            try? archive.addEntry(with: "OEBPS/" + chapterURL.lastPathComponent, relativeTo: url)
        }
        
        let chapterManifests = chapterData.map { $0.manifest }
        let spineItems = chapterData.map { itemRef.render(data: ["id": $0.filename]) }
        
        // Create manifest
        let manifestString = contentManifest.render(data: [
            "title": oneLineTitle,
            "authors": authors,
            "date": dateTime,
            "toc": "",
            "uuid": UUID().uuidString,
            "spine-items": spineItems.joined(separator: "\n"),
            "manifest" : chapterManifests.joined(separator: "\n")
        ])
        let manifestURL = URL(fileURLWithPath: OEBPSPath + "content.opf")
        try? manifestString.write(to: manifestURL, atomically: true, encoding: .utf8)
        try? archive.addEntry(with: "OEBPS/" + manifestURL.lastPathComponent, relativeTo: url)

        
        // Create TOC
        let tocItems = chapterData.map { tocLink.render(data: ["fileName": $0.filename, "title": ($0.title.count > 0) ? $0.title : "---"]) }
        let tocURL = URL(fileURLWithPath: OEBPSPath + "toc.xhtml")
        
        let toc = self.toc.render(data: ["toc-items": tocItems.joined(separator: "\n")])
        try? toc.write(to: tocURL, atomically: true, encoding: .utf8)
        try? archive.addEntry(with: "OEBPS/" + tocURL.lastPathComponent, relativeTo: url)
        
        let chapterNavPoints = chapterData.map { $0.navPoint }
        let tocNCX = tocNCX.render(data: [
            "title": oneLineTitle,
            "navPoints": chapterNavPoints.joined(separator: "\n")
        ])
        let tocNCXURL = URL(fileURLWithPath: OEBPSPath + "toc.ncx")
        try? tocNCX.write(to: tocNCXURL, atomically: true, encoding: .utf8)
        try? archive.addEntry(with: "OEBPS/" + tocNCXURL.lastPathComponent, relativeTo: url)
        
        if !FileManager.default.fileExists(atPath: ePubPath, isDirectory: nil) {
            print("Couldn't create directory")
            return nil
        }
        
        print("url",url)
        
        //try? FileManager.default.zipItem(at: url, to: zipUrl, shouldKeepParent: false, compressionMethod: .none)
        //print("   zip:", url)
        let data = try? Data(contentsOf: zipUrl)
        return data
    }
    
    func chapters() -> [[Line]] {
        var chapters:[[Line]] = []
        var currentChapter:[Line] = []
                
        for line in document.lines ?? [] {
            if line.type == .section && line.sectionDepth < 3 && currentChapter.count > 0 {
                chapters.append(currentChapter)
                currentChapter = []
            }
            
            currentChapter.append(line)
        }
        
        if currentChapter.count > 0 { chapters.append(currentChapter) }
        
        return chapters
    }
    
    func chapterFiles() -> ([BeatEPubChapter]) {
        var chapterItems:[BeatEPubChapter] = []
        
        var i = 1
        
        for chapter in chapters() {
            // Create HTML and find chapter title
            let content = html(lines: chapter)
            var title = chapter.first?.stripFormatting().trimmingCharacters(in: .whitespaces) ?? "(none)"
            if title.count == 0 { title = "---" }
            
            // Create HTML content
            let data = [ "title": title, "body": content, "style": css ]
            let html = pageTemplate.render(data: data)
                        
            // Create manifest items and navigation points
            let fileName = "chapter-\(i)"
            
            let mItem = manifestItem.render(data: [ "filename": fileName ])
            let navItem = navPoint.render(data: [ "id": fileName, "order": String(i), "title": title ])
            
            let chapterItem = BeatEPubChapter(title: title, filename: fileName, html: html, manifest: mItem, navPoint: navItem)
            chapterItems.append(chapterItem)
            
            i += 1
        }
        
        return chapterItems
    }
    
    func html(lines:[Line]) -> String {
        var html = ""
        for line in lines {
            html += lineToHTML(line)
        }
        
        return html
    }
    
    func lineToHTML(_ line:Line) -> String {
        guard let attrStr = line.attributedStringForOutput(with: self.settings) else { return "" }
        var html = ""
        var tag = ""
        var classes:[String] = []
        
        if line.type == .section { tag = "h" + String(line.sectionDepth) }
        else { tag = "p" }
        
        if line.type == .heading || line.type == .centered || line.type == .lyrics { classes.append(line.typeName()) }
        if line.beginsNewParagraph { classes.append("first") }
        
        // Create stylized HTML content from attributed string
        var content = ""
        attrStr.enumerateAttribute(NSAttributedString.Key("Style"), in: NSMakeRange(0, attrStr.length), using: { value, range, stop in
            var tags:[String] = []

            if let styles = value as? Set<String> {
                if styles.contains("Bold") { tags.append("b") }
                if styles.contains("Italic") { tags.append("i") }
                if styles.contains("BoldItalic") { tags.append("b"); tags.append("i") }
                if styles.contains("Underline") { tags.append("u") }
            }
            
            var fragment = attrStr.string.substring(range: range).replacingOccurrences(of: "<", with: "&lt;")
            
            for tag in tags {
                fragment = "<\(tag)>" + fragment + "</\(tag)>"
            }
            
            content += fragment
        })
        
        if line.type == .heading { content = "•••" }
        
        html = "<\(tag) class='\(classes.joined(separator: " "))'>" + content + "</\(tag)>\n"
        
        return html
    }
}

/// Minimal template engine
class Template {
    var template: String = ""
    
    init(templateURL: String) {
        let template = self.importFile(templateURL)
        self.template = self.preprocess(template)
    }
    init(template:String) {
        self.template = template
    }
    
    private func importFile(_ fileURL: String) -> String {
        guard let content = try? String(contentsOfFile: fileURL) else {
            return ""
        }
        return content
    }
    
    /// Preprocesses the template on load and includes imported files
    private func preprocess(_ template: String) -> String {
        return processMacro(template, open: "{%", close: "%}", data: [:]) { (key, data) in
            let components = key.components(separatedBy: " ")
            guard components.count > 0 else { return "" }
            
            if components[0] == "import" {
                if components.count > 1 {
                    return self.importFile(components[1])
                }
            }
            
            return ""
        }
    }
    
    /// Processes a string and executes a closure when something inside open/close tags is encountered.
    private func processMacro(_ template: String, open: String, close: String, data: [String: String], handler: (_ key: String, _ data: [String: String]) -> String) -> String {
        var pos = template.startIndex
        var result = ""
        var stop = false
        
        while !stop {
            if let start = template.range(of: open, range: pos..<template.endIndex) {
                if let end = template.range(of: close, range: start.upperBound..<template.endIndex) {
                    let limit = template[pos..<start.lowerBound]
                    result += limit
                    
                    let keyStart = start.upperBound
                    let keyEnd = end.lowerBound
                    let key = template[keyStart..<keyEnd].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    result += handler(key, data)
                    pos = end.upperBound
                    
                    if pos >= template.endIndex {
                        break
                    }
                } else {
                    stop = true
                }
            } else {
                stop = true
            }
        }
        
        result += String(template[pos..<template.endIndex])
        return result
    }
    
    /// Renders the actual string
    func render(data: [String: String]) -> String {
        return processMacro(template, open: "{{", close: "}}", data: data) { (key, data) in
            if let value = data[key] {
                return value
            } else {
                return ""
            }
        }
    }
}
