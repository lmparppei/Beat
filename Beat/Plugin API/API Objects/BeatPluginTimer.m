//
//  BeatPluginTimer.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.6.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginTimer.h"

@interface BeatPluginTimer ()
@property (nonatomic) NSTimer *timer;
@end

@implementation BeatPluginTimer

+(BeatPluginTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer * _Nonnull))block {
	BeatPluginTimer *timer = [[BeatPluginTimer alloc] init];
	timer.timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:repeats block:block];
	
	return timer;
}

- (void)stop {
	[_timer invalidate];
}
- (void)invalidate {
	[_timer invalidate];
}
- (void)start {
	[_timer setFireDate:[NSDate date]];
}
- (bool)running {
	return [self.timer isValid];
}
- (bool)isValid {
	return [self.timer isValid];
}


@end
