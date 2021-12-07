//
//  BeatPluginUIButton.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatPluginUIButton : NSButton
+(instancetype)buttonWithTitle:(NSString *)title action:(JSValue*)action frame:(NSRect)frame;
@end

NS_ASSUME_NONNULL_END
