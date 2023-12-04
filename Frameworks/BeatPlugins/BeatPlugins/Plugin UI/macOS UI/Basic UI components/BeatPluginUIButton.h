//
//  BeatPluginUIButton.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IOS
#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "BeatPluginUIExports.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BeatPluginUIButtonExports <JSExport>
@property (nonatomic) NSString* title;
@property (nonatomic) bool enabled;
- (void)setTitle:(NSString * _Nonnull)title;
@end

@interface BeatPluginUIButton : NSButton <BeatPluginUIButtonExports, BeatPluginUIExports>
+ (instancetype)buttonWithTitle:(NSString *)title action:(JSValue*)action frame:(NSRect)frame;
@end

NS_ASSUME_NONNULL_END

#endif
