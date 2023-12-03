//
//  BeatPluginUICheckbox.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatPlugins/BeatPluginUIExports.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatPluginUICheckboxExports <JSExport>
@property (nonatomic) bool checked;
@property (nonatomic) NSString *title;
@property (nonatomic) bool *enabled;
- (void)setChecked:(bool)checked;
@end

@interface BeatPluginUICheckbox : NSButton <BeatPluginUICheckboxExports, BeatPluginUIExports>
+ (BeatPluginUICheckbox*)withTitle:(NSString*)title action:(JSValue*)action frame:(NSRect)frame;
@end

NS_ASSUME_NONNULL_END
