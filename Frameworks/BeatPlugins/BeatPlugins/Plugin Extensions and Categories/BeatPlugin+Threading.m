//
//  BeatPlugin+Threading.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatPlugin+Threading.h"

@implementation BeatPlugin (Threading)


#pragma mark - Basic multithreading support for plugins

/// Shorthand for `dispatch()`
- (void)async:(JSValue*)callback
{
    [self dispatch:callback];
}
/// Shorthand for `dispatch_sync()`
- (void)sync:(JSValue*)callback
{
    [self dispatch_sync:callback];
}

/// Runs the given block in a **background thread**
- (void)dispatch:(JSValue*)callback
{
    [self dispatch:callback priority:0];
}
/// Runs the given block in a background thread
- (void)dispatch:(JSValue*)callback priority:(NSInteger)priority
{
    intptr_t p;
    
    switch (priority) {
        case 1:
            p = DISPATCH_QUEUE_PRIORITY_BACKGROUND; break;
        case 2:
            p = DISPATCH_QUEUE_PRIORITY_LOW; break;
        case 3:
            p = DISPATCH_QUEUE_PRIORITY_DEFAULT; break;
        case 4:
            p = DISPATCH_QUEUE_PRIORITY_HIGH; break;
        default:
            p = DISPATCH_QUEUE_PRIORITY_DEFAULT;
            break;
    }
    
    dispatch_async(dispatch_get_global_queue(p, 0), ^(void) {
        [callback callWithArguments:nil];
    });
}
/// Runs the given block in **main thread**
- (void)dispatch_sync:(JSValue*)callback
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [callback callWithArguments:nil];
    });
}

- (bool)isMainThread { return NSThread.isMainThread; }


@end
