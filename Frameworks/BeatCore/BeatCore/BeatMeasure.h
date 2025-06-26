//
//  BeatMeasure.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatMeasure : NSObject
+ (BeatMeasure*)shared;
+ (void)start:(NSString*)name;
+ (void)end:(NSString*)name;
+ (NSTimeInterval)getTime:(NSString*)name;
+ (NSTimeInterval)getTimeAndEnd:(NSString*)name;
+ (NSString*)endAndReturnString:(NSString*)name;

/// Starts a new *queue* of time measurements. Never use the same name for a single measurement.
+ (void)startQueue:(NSString*)name;
/// Starts a new phase in the measurements, ending the previous one (if there's one)
+ (void)queue:(NSString*)name startPhase:(NSString*)phaseName;
/// Ends the whole queue and returns the array of dictionaries: `["name": String, "start": NSDate, "executionTime": NSNumber<Float>]`
+ (NSArray<NSMutableDictionary*>*)getAndEndQueue:(NSString*)name;


@end

NS_ASSUME_NONNULL_END
