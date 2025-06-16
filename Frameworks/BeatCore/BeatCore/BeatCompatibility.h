//
//  BeatCompatibility.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 25.7.2023.
//

#if TARGET_OS_IOS

    #define BXColor UIColor
    #define BXView UIView
    #define BXTextView UITextView
    #define textViewNeedsDisplay setNeedsDisplay

    #define BXFont UIFont
    #define BXWindow UIWindow
    #define BXPrintInfo UIPrintInfo
    #define BXImage UIImage

    #define BXChangeType UIDocumentChangeKind
    #define BXChangeDone UIDocumentChangeDone

    #define is_Mobile (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)

    #define __OS_KIT <UIKit/UIKit.h>

#else

    #define BXColor NSColor
    #define BXView NSView
    #define BXTextView NSTextView
    #define textViewNeedsDisplay setNeedsDisplay:true

    #define BXFont NSFont
    
    #define BXWindow NSWindow
    #define BXPrintInfo NSPrintInfo
    #define BXImage NSImage

    #define BXChangeType NSDocumentChangeType
    #define BXChangeDone NSChangeDone

    #define __OS_KIT <AppKit/AppKit.h>

#endif

// Shorthand for comparing bitmasks
#define mask_contains(mask, bit) (mask & bit) == bit

// This is AI-generated slop, sorry, but I was in a hurry.
#define CLAMP_RANGE(range, maxLength) ({ \
    NSRange _r = (range); \
    NSUInteger _max = (maxLength); \
    if (_r.location >= _max) { \
        _r.length = 0; \
    } else if (_r.location + _r.length > _max) { \
        _r.length = _max - _r.location; \
    } \
    _r; \
})

#define ToAttributedString(string) [[NSAttributedString alloc] initWithString:string]
