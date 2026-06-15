//
//  NSAttributedString+ConvertToFountain.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 8.10.2025.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

@interface NSAttributedString (ConvertToFountain)

/// Converts a system attributed string to Fountain. Quality may vary.
- (NSString*)convertToFountain;

@end
