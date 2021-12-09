//
//  BeatWidgetView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BeatPluginUIView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatWidgetView : NSView
- (void)addWidget:(BeatPluginUIView*)widget;
- (void)removeWidget:(BeatPluginUIView*)widget;
@end


NS_ASSUME_NONNULL_END
