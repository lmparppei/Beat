//
//  NSTextView+UX.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//

#import <TargetConditionals.h>
#import <BeatCore/BeatCompatibility.h>

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

@interface BXTextView (UX)
#if TARGET_OS_OSX
@property (nonatomic) NSString* text;
@property (nonatomic) NSAttributedString* attributedText;
#else
@property (nonatomic) NSString* string;
@property (nonatomic) NSAttributedString* attributedString;
- (void)didChangeText;
- (UITextRange*)textRangeFrom:(NSRange)range;
#endif
@end


