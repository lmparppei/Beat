//
//  BeatWidgetView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif
#import <BeatPlugins/BeatPluginUIView.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS
@interface BeatWidgetView : UIView
#else
@interface BeatWidgetView : NSView
- (void)addWidget:(BeatPluginUIView*)widget;
- (void)removeWidget:(BeatPluginUIView*)widget;
- (void)repositionWidgets;
- (void)show:(BeatPluginUIView*)widget;
#endif
@end


NS_ASSUME_NONNULL_END
