//
//  BeatMeasure.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 A simple class to measure execution times
 
 */

#import "BeatMeasure.h"

@interface BeatMeasure()
@property (nonatomic) NSMutableDictionary *measurements;
@end

@implementation BeatMeasure

+ (BeatMeasure*)shared
{
	static BeatMeasure* sharedMeasure;
	if (!sharedMeasure) {
		sharedMeasure = [[BeatMeasure alloc] init];
	}
	return sharedMeasure;
}

- (void)start:(NSString*)name {
	if (!_measurements) _measurements = [NSMutableDictionary dictionary];
	_measurements[name] = [NSDate date];
}

+ (void)start:(NSString*)name
{
	[BeatMeasure.shared start:name];
}
+ (void)end:(NSString*)name
{
	NSLog(@"%@ execution time = %f", name, [BeatMeasure getTime:name]);
	
	[BeatMeasure.shared.measurements removeObjectForKey:name];
}

+ (NSTimeInterval)getTimeAndEnd:(NSString*)name
{
    NSTimeInterval executionTime = [BeatMeasure getTime:name];
    [BeatMeasure.shared.measurements removeObjectForKey:name];
    return executionTime;
}

+ (NSTimeInterval)getTime:(NSString*)name {
	NSDate *methodFinish = [NSDate date];
	NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:(NSDate*)BeatMeasure.shared.measurements[name]];
	return executionTime;
}

+ (NSString*)endAndReturnString:(NSString*)name {
	NSString *string = [NSString stringWithFormat:@"%f", [BeatMeasure getTime:name]];
	[BeatMeasure.shared.measurements removeObjectForKey:name];
	return string;
}

/// Starts a new *queue* of time measurements. Never use the same name for a single measurement.
+ (void)startQueue:(NSString*)name
{
    NSMutableArray* measurements = NSMutableArray.new;
    BeatMeasure.shared.measurements[name] = measurements;
}
/// Starts a new phase in the measurements
+ (void)queue:(NSString*)name startPhase:(NSString*)phaseName
{
    // Phase item: [phase, start, end]
    NSMutableArray<NSMutableDictionary*>* queue = BeatMeasure.shared.measurements[name];
    NSMutableDictionary* previousPhase = queue.lastObject;
    if (previousPhase != nil) {
        NSTimeInterval interval = [NSDate.new timeIntervalSinceDate:previousPhase[@"start"]];
        previousPhase[@"executionTime"] = @(interval);
    }
    
    NSMutableDictionary* phase = [NSMutableDictionary dictionaryWithDictionary:@{
        @"name": phaseName,
        @"start": NSDate.new
    }];
    [queue addObject:phase];
}
/// Ends the whole queue and returns the array of dictionaries.
+ (NSArray<NSMutableDictionary*>*)getAndEndQueue:(NSString*)name
{
    NSArray* phases = BeatMeasure.shared.measurements[name];
    NSMutableDictionary* lastPhase = phases.lastObject;
    if (lastPhase != nil) {
        NSTimeInterval interval = [NSDate.new timeIntervalSinceDate:lastPhase[@"start"]];
        lastPhase[@"executionTime"] = @(interval);
    }
    
    [BeatMeasure.shared.measurements removeObjectForKey:name];
    return phases;
}

@end
/*
 
 the music's out
 we used to play it so loud
 just before we'd hit the town
 but we grow old
 kings give up their thrones
 and no one wants to be alone
 
 */
