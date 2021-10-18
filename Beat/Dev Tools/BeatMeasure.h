//
//  BeatMeasure.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatMeasure : NSObject
+ (BeatMeasure*)shared;
+ (void)start:(NSString*)name;
+ (void)end:(NSString*)name;
@end

NS_ASSUME_NONNULL_END
