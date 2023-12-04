//
//  BeatPluginUIExports.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <JavaScriptCore/JavaScriptCore.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#define BXView UIView
#else
#import <AppKit/AppKit.h>
#define BXView NSView
#endif

@protocol BeatPluginUIExports <JSExport>

@property (nonatomic) CGRect frame;
- (void)remove;
- (void)setFrame:(CGRect)frame;

@end
