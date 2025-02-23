//
//  NSMutableAttributedString+BeatAttributes.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 10.2.2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableAttributedString (BeatAttributes)

/// N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for both internal rendering and FDX conversion.
- (void)addBeatStyleAttr:(NSString*)name range:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
