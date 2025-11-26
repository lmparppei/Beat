//
//  main.swift
//  Beat CLI
//
//  Created by Lauri-Matti Parppei on 25.11.2025.
//
/**
 
 This is a bare-bones command-line interface for creating PDF files from Fountain
 
 */

import Foundation
import BeatParsing
import BeatCore
import BeatPagination2
import ArgumentParser


@main
struct BeatCLI:ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Command-line interface for (beat)",
        subcommands: [CreatePDF.self]
    )
    
    func run() throws {
        print("(beat) CLI interface\nUsage: beat-cli pdf [source] [target] [options]. Use 'beat-cli pdf --help' for more help.")
    }
    
}

struct CreatePDF: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pdf",
        abstract: "Create a PDF from a source file"
    )
    
    @Argument(help: "Path to source Fountain file")
    var fountainURL:String
    
    @Argument(help: "Path to target PDF file")
    var pdfURL:String
    
    @Option(name: .shortAndLong, help: "Paper Size: a4/letter")
    var pageSize:String?
    
	@Flag(wrappedValue: false, name: .shortAndLong, help: "Don't print scene numbers")
	var noSceneNumbers:Bool
	
	@Option(name: .shortAndLong, help: "Select invisible elements to be printed, ie. --invisible-elements notes sections synopses")
	var invisibleElements:String?
	
	
    @Option(name: .shortAndLong, help: "Header text")
    var header:String?
    
    var args = CommandLine.arguments
        
    public func run() throws {
        if args.count < 2 {
            print("Usage: beat-cli operation file target args")
            return
        }
        
        BeatCLI.registerFonts()
        
        let operation = args[1].lowercased()
    
        if operation == "pdf" {
            createPDF()
        }
    }
        
    func createPDF() {
        let fountainURL = URL(filePath: self.fountainURL)
        let pdfURL = URL(filePath: self.pdfURL)
        
        guard fountainURL.startAccessingSecurityScopedResource() else {
            print("Can't access source file")
            return
        }
        
        // Fetch string
        var string:String
        do {
            string = try String(contentsOf: fountainURL, encoding: .utf8)
        } catch {
            print("ERROR: Failed to read the source file at",fountainURL)
            print(error)
            return
        }
        
        let settings = BeatDocumentSettings()
        let range = settings.readAndReturnRange(string)
        let fountain = string.substring(range: range)
                
        let parser = ContinuousFountainParser(staticParsingWith: fountain, settings: settings)
        
        let exportSettings = BeatExportSettings()
        exportSettings.paperSize = BeatPaperSize(rawValue: settings.getInt(DocSettingPageSize)) ?? .A4
        exportSettings.documentSettings = settings
        
        appendCustomArguments(to: exportSettings)
        
        guard let screenplay = BeatScreenplay.from(parser, settings: exportSettings) else {
            print("Failed to create screenplay from source")
            return
        }
        
        print("Create PDF from", fountainURL.lastPathComponent)
        _ = BeatPrintView(window: nil, operation: .toFile, settings: exportSettings, delegate: nil, screenplays: [screenplay]) { printView, result in
            CFRunLoopStop(CFRunLoopGetMain())
            if let tempURL = result as? URL {
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: pdfURL.path()) {
                        _ = try fm.replaceItemAt(pdfURL, withItemAt: tempURL)
                    } else {
                        try fm.copyItem(at: tempURL, to: pdfURL)
                    }
                    
                    print("PDF created successfully at:", pdfURL)
                } catch {
                    print("Can't copy to destination URL:", error)
                }
            }
            return
        }
        CFRunLoopRun()
    }
    
    func appendCustomArguments(to exportSettings:BeatExportSettings) {
        if noSceneNumbers {
            exportSettings.printSceneNumbers = false
        }
		
        if let pageSize {
            exportSettings.paperSize = pageSize == "a4" ? .A4 : .usLetter
        }
		
        if let header {
            exportSettings.header = header
        }
		
		if let invisibleElements {
			var elements = invisibleElements.lowercased().components(separatedBy: " ")
			
			if elements.contains("notes") {
				exportSettings.invisibleElements.insert(.includeNotes)
				elements.removeObject(object: "notes")
			}
			if elements.contains("sections") {
				exportSettings.invisibleElements.insert(.includeSynopsis)
				elements.removeObject(object: "sections")
			}
			if elements.contains("synopses") {
				exportSettings.invisibleElements.insert(.includeSynopsis)
				elements.removeObject(object: "synopses")
			}
			
			if elements.count > 0 {
				print("Unrecognized invisible elements:", elements)
			}
		}
    }
}
