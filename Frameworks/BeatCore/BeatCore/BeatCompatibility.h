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

#else

    #define BXColor NSColor
    #define BXView NSView
    #define BXTextView NSTextView
    #define textViewNeedsDisplay setNeedsDisplay:true

#endif
