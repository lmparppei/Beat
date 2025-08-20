//
//  BeatRenderer+Outline.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 8.8.2025.
//

import PDFKit

extension BeatRenderer {
    
    /// Helper static method for  creating PDF outline (table of contents) in an existing PDF, based on pre-created placeholder items.
    /// - note: We absolutely *could* create these on the fly while creating the actual PDF file, but iOS and macOS use a different approach to creating PDF files. On macOS, the same code is used for both PDF creation and printing, while on iOS we are going for a more traditional PDF output. By doing it "in the post", we have unified way of doing it.
    static public func createOutlineForPDF(at url: URL, outline:[BeatPDFDestination]) {
        let pdfOutline = PDFOutline()
        var i = 0
        if let pdf = PDFDocument(url: url) {
            for item in outline {
                let outlineItem = PDFOutline()
                outlineItem.label = item.label
                
                if let page = pdf.page(at: item.pageIndex) {
                    let pageBounds = page.bounds(for: .artBox)
                    let factor = pageBounds.height / item.pageSize.height
                    let point = CGPoint(x: factor * item.point.x, y: factor * item.point.y)
                    
                    outlineItem.destination = PDFDestination(page: page, at: point)
                    pdfOutline.insertChild(outlineItem, at: i)
                    i += 1
                }
            }
            
            pdf.outlineRoot = pdfOutline
            pdf.write(to: url)
        }
    }
    
}
