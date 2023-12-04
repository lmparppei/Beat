//
//  BeatPluginUI.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUI.h"
#import "BeatPluginUIView.h"

@implementation BeatPluginUI

#if !TARGET_OS_IOS

- (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUIButton buttonWithTitle:name action:action frame:frame];
}
- (BeatPluginUIDropdown*)dropdown:(nonnull NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUIDropdown withItems:items action:action frame:frame];
}
- (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUICheckbox withTitle:title action:action frame:frame];
}
- (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName
{
	return [BeatPluginUILabel withText:title frame:frame color:color size:size font:fontName];
}
- (BeatPluginUITextField*)textField:(NSString*)title frame:(NSRect)frame action:(JSValue*)action color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName
{
	return [BeatPluginUITextField withText:title frame:frame onChange:action color:color size:size font:fontName];
}

#endif

@end
