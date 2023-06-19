//
//  BeatAttributes.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 29.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatAttributes : NSObject
@property (nonatomic) NSMutableSet *keys;
+ (BeatAttributes*)shared;
+ (void)registerAttribute:(NSString*)key;
+ (BOOL)containsCustomAttributes:(NSDictionary*)dict;
+ (NSDictionary*)stripUnnecessaryAttributesFrom:(NSDictionary*)attrs;
@end

NS_ASSUME_NONNULL_END
