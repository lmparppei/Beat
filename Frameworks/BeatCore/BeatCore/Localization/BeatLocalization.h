//
//  BeatLocalization.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatLocalization : NSObject
/// Iterates through a string and replaces all instances of `#key#` with localized strings. Always falls back to English if localization is not available.
+ (NSString*)localizeString:(NSString*)string;
/// Returns only the localized value for given string, and falls back to English if it's not available.
+ (NSString*)localizedStringForKey:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
