//
//  NSTextView+UX.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//
//  Basic interop for macOS / iOS text views for ObjC

#import "NSTextView+UX.h"

#if !TARGET_OS_IOS
@implementation NSTextView (UX)

- (NSString*)text {
	return self.string;
}
-(void)setText:(NSString *)text {
	self.string = text;
}

@end
#endif
