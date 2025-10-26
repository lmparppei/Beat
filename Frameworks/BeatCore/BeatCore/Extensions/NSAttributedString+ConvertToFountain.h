//
//  NSAttributedString+ConvertToFountain.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 8.10.2025.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (ConvertToFountain)

/// Converts a system attributed string to Fountain. Quality may vary.
- (NSString*)convertToFountain;

@end
