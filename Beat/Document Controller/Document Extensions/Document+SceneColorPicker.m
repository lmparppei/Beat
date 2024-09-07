//
//  Document+SceneColorPicker.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+SceneColorPicker.h"
#import "Beat-Swift.h"

@implementation Document (SceneColorPicker)

#pragma mark - Color picker

- (void)setupColorPicker
{
	for (NSTouchBarItem *item in [self.textView.touchBar templateItems]) {
		if ([item.className isEqualTo:@"NSColorPickerTouchBarItem"]) {
			NSColorPickerTouchBarItem *picker = (NSColorPickerTouchBarItem*)item;
			
			self.colorPicker = picker;
			picker.showsAlpha = NO;
			picker.colorList = [[NSColorList alloc] init];
			
			[picker.colorList setColor:NSColor.blackColor forKey:@"none"];
			
			// Append Beat colors to list
			NSArray* colors = @[@"red", @"blue", @"green", @"cyan", @"orange", @"pink", @"gray", @"magenta"];
			for (NSString* color in colors) [picker.colorList setColor:[BeatColors color:color] forKey:color];
		}
	}
}

- (IBAction)pickColor:(id)sender
{
	NSString *pickedColor;
	for (NSString *color in BeatColors.colors) {
		if ([self.colorPicker.color isEqualTo:[BeatColors color:color]]) {
			pickedColor = color; return;
		}
	}
	
	if ([self.colorPicker.color isEqualTo:NSColor.blackColor]) pickedColor = @"none"; 	// The house is black.
	
	if (self.currentScene != nil && pickedColor != nil) {
		[self.textActions setColor:pickedColor forScene:self.currentScene];
	}
}

- (IBAction)setSceneColorForRange:(id)sender
{
	// Called from text view context menu
	BeatColorMenuItem *item = sender;
	NSString *color = item.colorKey;
	
	NSRange range = self.selectedRange;
	NSArray *scenes = [self.parser scenesInRange:range];
		
	for (OutlineScene* scene in scenes) {
		[self.textActions setColor:color forScene:scene];
	}
}

@end
