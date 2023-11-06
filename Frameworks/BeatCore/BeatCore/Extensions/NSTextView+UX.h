//
//  NSTextView+UX.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//

#import <TargetConditionals.h>


#if !TARGET_OS_IOS
#define BXTextView NSTextView
#import <Cocoa/Cocoa.h>

@interface NSTextView (UX)
@property (nonatomic) NSString* text;
@end

#endif
