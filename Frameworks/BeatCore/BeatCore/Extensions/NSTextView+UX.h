//
//  NSTextView+UX.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//

#import <TargetConditionals.h>

#define BXTextView NSTextView

#if !TARGET_OS_IOS
#import <Cocoa/Cocoa.h>

@interface NSTextView (UX)
@property (nonatomic) NSString* text;
@end

#endif
