//
//  BeatPluginTimer.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.6.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatPluginTimerExports <JSExport>
- (void)invalidate;
- (void)stop;
- (void)start;
- (bool)running;
@end
@interface BeatPluginTimer : NSObject <BeatPluginTimerExports>
+(BeatPluginTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer * _Nonnull))block;
- (void)invalidate;
- (void)stop;
- (void)start;
- (bool)running;
- (bool)isValid;
@end

NS_ASSUME_NONNULL_END
