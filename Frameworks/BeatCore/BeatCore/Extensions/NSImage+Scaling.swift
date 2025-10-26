//
//  NSImage+Scaling.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 27.2.2025.
//

#if os(macOS)

import AppKit

public extension NSImage {
    func tinting(with tintColor: NSColor) -> NSImage {
        if #available(macOS 12.0, *) {
            let symbolConfiguration = self.symbolConfiguration
            
            var tintedSymbolImage = self.copy() as! NSImage
            if tintedSymbolImage.size == NSSize.zero {
                return tintedSymbolImage
            }
            
            tintedSymbolImage.lockFocus()
            
            // Apply the tint color
            tintColor.set()
            NSRect(origin: .zero, size: self.size).fill(using: .sourceAtop)
            
            tintedSymbolImage.unlockFocus()
            
            tintedSymbolImage.isTemplate = true
            tintedSymbolImage = tintedSymbolImage.withSymbolConfiguration(symbolConfiguration)!
            
            return tintedSymbolImage
        } else {
            return self
        }
    }
    
    func rotated(by degrees : CGFloat) -> NSImage {
        var imageBounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let rotatedSize = AffineTransform(rotationByDegrees: degrees).transform(size)
        let newSize = CGSize(width: abs(rotatedSize.width), height: abs(rotatedSize.height))
        let rotatedImage = NSImage(size: newSize)

        imageBounds.origin = CGPoint(x: newSize.width / 2 - imageBounds.width / 2, y: newSize.height / 2 - imageBounds.height / 2)

        let otherTransform = NSAffineTransform()
        otherTransform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        otherTransform.rotate(byDegrees: degrees)
        otherTransform.translateX(by: -newSize.width / 2, yBy: -newSize.height / 2)

        rotatedImage.lockFocus()
        otherTransform.concat()
        draw(in: imageBounds, from: CGRect.zero, operation: NSCompositingOperation.copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
    
    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            NSGraphicsContext.current?.imageInterpolation = .high
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            
            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }
        
        return nil
    }
}

#endif
