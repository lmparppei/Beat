//
//  BeatPlugin+Timer.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatPlugin+Timer.h"
#import "BeatPluginTimer.h"

@implementation BeatPlugin (Timer)

#pragma mark - Timer

/// Creates a `BeatPluginTimer` object, which fires after the given interval (seconds)
- (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats
{
    BeatPluginTimer *timer = [BeatPluginTimer scheduledTimerWithTimeInterval:seconds repeats:repeats block:^(NSTimer * _Nonnull timer) {
        [self runCallback:callback withArguments:nil];
    }];
    
    // When adding a new timer, remove references to invalid ones
    [self cleanInvalidTimers];
    
    // Add the new timer to timer array
    if (!self.timers) self.timers = NSMutableArray.new;
    [self.timers addObject:timer];
        
    return timer;
}

/// Removes unused timers from memory.
- (void)cleanInvalidTimers
{
    NSMutableArray *timers = NSMutableArray.new;
    
    for (int i=0; i < self.timers.count; i++) {
        BeatPluginTimer *timer = self.timers[i];
        if (timer.isValid) [timers addObject:timer];
    }
    
    self.timers = timers;
}

@end
