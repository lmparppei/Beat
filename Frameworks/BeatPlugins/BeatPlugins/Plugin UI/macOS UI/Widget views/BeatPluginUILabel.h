//
//  BeatPluginUILabel.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatPlugins/BeatPluginUIExports.h>

@protocol BeatPluginUILabelExports <JSExport>
@property (nonatomic) NSString *title;
@property (strong, nonatomic) NSString *color;
@property (nonatomic) NSString *fontName;
@property (nonatomic) CGFloat fontSize;
@end

@interface BeatPluginUILabel : NSTextField <BeatPluginUILabelExports, BeatPluginUIExports>
@property (nonatomic) NSString *title;
@property (strong, nonatomic) NSString *color;
@property (nonatomic) NSString *fontName;
@property (nonatomic) CGFloat fontSize;

+ (BeatPluginUILabel*)withText:(NSString*)title frame:(NSRect)frame color:(NSString*)colorName size:(CGFloat)fontSize font:(NSString*)fontName;
@end

