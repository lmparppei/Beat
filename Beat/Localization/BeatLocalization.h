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
+ (NSString*)localizeString:(NSString*)string;
+ (NSString*)localizedStringForKey:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
