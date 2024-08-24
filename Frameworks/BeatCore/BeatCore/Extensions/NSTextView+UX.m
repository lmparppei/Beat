//
//  NSTextView+UX.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//
//  Basic interop for macOS / iOS text views for ObjC

#import "NSTextView+UX.h"

#if TARGET_OS_OSX
@implementation NSTextView (UX)
#else
@implementation UITextView (UX)
#endif

#if TARGET_OS_OSX
#pragma mark - macOS

- (NSString*)text { return self.string; }
- (void)setText:(NSString *)text { self.string = text; }
- (NSAttributedString*)attributedText { return self.attributedString; }
- (void)setAttributedText:(NSAttributedString*)text { [self.textStorage setAttributedString:text]; }

#else
#pragma mark - iOS

- (NSString*)string { return self.text; }
- (void)setString:(NSString*)string { self.text = string; }
- (NSAttributedString*)attributedString { return self.attributedText; }
- (void)setAttributedString:(NSAttributedString*)string { [self setAttributedText:string]; }

- (void)didChangeText
{
    // This does nothing on iOS, but might be overriden somewhere, so... uh.
    NSLog(@"!!! didChangeText called on iOS. Was this intentional?");
}

- (UITextRange*)textRangeFrom:(NSRange)range
{
    UITextPosition *beginning = self.beginningOfDocument;
    UITextPosition *start = [self positionFromPosition:beginning offset:range.location];
    UITextPosition *end = [self positionFromPosition:start offset:range.length];
    
    return [self textRangeFromPosition:start toPosition:end];
}

#endif
@end
