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

@end
/*
 
 the music's out
 we used to play it so loud
 just before we'd hit the town
 but we grow old
 kings give up their thrones
 and no one wants to be alone
 
 */
