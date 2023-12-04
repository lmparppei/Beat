//
//  BeatPluginUITextField.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUITextField.h"
#import <BeatCore/BeatCore.h>

@implementation BeatPluginUITextField

+ (BeatPluginUITextField*)withText:(NSString*)title frame:(NSRect)frame onChange:(JSValue*)action color:(NSString*)colorName size:(CGFloat)fontSize font:(NSString*)fontName
{
	BeatPluginUITextField* textField = [BeatPluginUITextField.alloc initWithFrame:frame];
	textField.jsAction = action;
	
	textField.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
	if (fontName != nil) textField.font = [NSFont fontWithName:fontName size:fontSize];
	else if (fontSize > 0) if (@available(macOS 10.15, *)) {
		textField.font = [textField.font fontWithSize:fontSize];
	}
	
	if (colorName != nil) {
		NSColor* color = [BeatColors color:colorName];
		if (color != nil) textField.textColor = color;
	}
	
	return textField;
}

- (void)remove {
	[self removeFromSuperview];
}

- (NSString*)value {
	return self.stringValue;
}

- (void)controlTextDidChange:(NSNotification *)obj {
	[_jsAction callWithArguments:@[self.stringValue]];
}

@end
