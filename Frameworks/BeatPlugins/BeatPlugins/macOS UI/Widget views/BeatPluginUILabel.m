//
//  BeatPluginUILabel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUILabel.h"
#import "BeatWidgetView.h"
#import <BeatCore/BeatColors.h>

@implementation BeatPluginUILabel 

+ (BeatPluginUILabel*)withText:(NSString*)title frame:(NSRect)frame color:(NSString*)colorName size:(CGFloat)fontSize font:(NSString*)fontName {
	BeatPluginUILabel* label = [BeatPluginUILabel.alloc initWithFrame:frame];
	label.drawsBackground = NO;
	label.bordered = NO;
	label.bezeled = NO;
	label.editable = NO;
	label.usesSingleLineMode = NO;
	
	if (!fontSize) fontSize = NSFont.smallSystemFontSize;
	
	NSColor *color;
	NSFont *font;
	
	if (!fontName) font = [NSFont systemFontOfSize:fontSize];
	else font = [NSFont fontWithName:fontName size:fontSize];
	
	if (!colorName) color = NSColor.labelColor;
	else color = [BeatColors color:colorName];
	
	label.font = font;
	label.textColor = color;
	
	label.stringValue = title;
	
	return label;
}

- (NSString*)title {
	return self.stringValue;
}
- (void)setTitle:(NSString*)title {
	self.stringValue = title;
}

- (void)setFontName:(NSString*)fontName {
	NSFont *font = self.font;
	NSFont *newFont = [NSFont fontWithName:fontName size:font.pointSize];
	self.font = newFont;
}

- (void)setFontSize:(CGFloat)fontSize {
	NSFont *font = self.font;
	NSFont *newFont = [NSFont fontWithName:font.fontName size:fontSize];
	self.font = newFont;
}

- (void)setColor:(NSString*)hexColor {
	self.textColor = [BeatColors color:hexColor];
	_color = hexColor;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.

}

- (void)remove {
	[self removeFromSuperview];
}

@end
