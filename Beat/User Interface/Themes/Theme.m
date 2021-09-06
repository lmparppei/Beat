//
//  Theme.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 04.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "Theme.h"

@implementation Theme

- (NSDictionary*)themeAsDictionary {
	return [self themeAsDictionaryWithName:self.name];
}
- (NSDictionary*)themeAsDictionaryWithName:(NSString*)name
{
	NSMutableDictionary *light = [NSMutableDictionary dictionary];
	NSMutableDictionary *dark = [NSMutableDictionary dictionary];
	
	if (self.backgroundColor) {
		NSArray *values = [self.backgroundColor valuesAsRGB];
		light[@"Background"] = values[0];
		dark[@"Background"] = values[1];
	}
	if (self.marginColor) {
		NSArray *values = [self.marginColor valuesAsRGB];
		light[@"Margin"] = values[0];
		dark[@"Margin"] = values[1];
	}
	if (self.selectionColor) {
		NSArray *values = [self.selectionColor valuesAsRGB];
		light[@"Selection"] = values[0];
		dark[@"Selection"] = values[1];
	}
	if (self.textColor) {
		NSArray *values = [self.textColor valuesAsRGB];
		light[@"Text"] = values[0];
		dark[@"Text"] = values[1];
	}
	if (self.commentColor) {
		NSArray *values = [self.commentColor valuesAsRGB];
		light[@"Comment"] = values[0];
		dark[@"Comment"] = values[1];
	}
	if (self.invisibleTextColor) {
		NSArray *values = [self.invisibleTextColor valuesAsRGB];
		light[@"InvisibleText"] = values[0];
		dark[@"InvisibleText"] = values[1];
	}
	if (self.caretColor) {
		NSArray *values = [self.caretColor valuesAsRGB];
		light[@"Caret"] = values[0];
		dark[@"Caret"] = values[1];
	}
	if (self.pageNumberColor) {
		NSArray *values = [self.pageNumberColor valuesAsRGB];
		light[@"PageNumber"] = values[0];
		dark[@"PageNumber"] = values[1];
	}
	if (self.synopsisTextColor) {
		NSArray *values = [self.synopsisTextColor valuesAsRGB];
		light[@"SynopsisText"] = values[0];
		dark[@"SynopsisText"] = values[1];
	}
	if (self.sectionTextColor) {
		NSArray *values = [self.sectionTextColor valuesAsRGB];
		light[@"SectionText"] = values[0];
		dark[@"SectionText"] = values[1];
	}
	if (self.outlineBackground) {
		NSArray *values = [self.outlineBackground valuesAsRGB];
		light[@"OutlineBackground"] = values[0];
		dark[@"OutlineBackground"] = values[1];
	}
	if (self.outlineHighlight) {
		NSArray *values = [self.outlineHighlight valuesAsRGB];
		light[@"OutlineHighlight"] = values[0];
		dark[@"OutlineHighlight"] = values[1];
	}
	if (self.highlightColor) {
		NSArray *values = [self.highlightColor valuesAsRGB];
		light[@"Highlight"] = values[0];
		dark[@"Highlight"] = values[1];
	}
		
	return @{ @"Name": name, @"Light": light, @"Dark": dark };
}

@end
