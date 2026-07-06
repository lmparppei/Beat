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
@property (nonatomic) NSMutableSet<NSString*>* keys;
@property (nonatomic) NSMutableSet<Class>* classes;
+ (BeatAttributes*)shared;
+ (void)registerAttribute:(NSString*)key class:(_Nullable Class)class;
+ (BOOL)containsCustomAttributes:(NSDictionary*)dict;
+ (NSDictionary*)stripUnnecessaryAttributesFrom:(NSDictionary*)attrs;
@end

NS_ASSUME_NONNULL_END
