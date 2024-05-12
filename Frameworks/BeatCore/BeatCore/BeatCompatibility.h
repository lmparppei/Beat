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
    #define BXChangeType UIDocumentChangeKind
    #define BXWindow UIWindow
    #define BXPrintInfo UIPrintInfo
    #define BXImage UIImage

    #define is_Mobile (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)

#else

    #define BXColor NSColor
    #define BXView NSView
    #define BXTextView NSTextView
    #define textViewNeedsDisplay setNeedsDisplay:true

    #define BXFont NSFont
    #define BXChangeType NSDocumentChangeType
    #define BXWindow NSWindow
    #define BXPrintInfo NSPrintInfo
    #define BXImage NSImage

#endif
