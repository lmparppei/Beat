//
//  BeatPlugin+Timer.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatPlugins/BeatPlugins.h>

@class BeatPluginTimer;

@protocol BeatPluginTimersExports <JSExport>

#pragma mark Timer
JSExportAs(timer, - (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats);

@end

@interface BeatPlugin (Timer) <BeatPluginTimersExports>

@end

