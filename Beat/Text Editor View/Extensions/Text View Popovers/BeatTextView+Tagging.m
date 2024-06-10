//
//  BeatTextView+Tagging.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 11.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+Tagging.h"
#import "Beat-Swift.h"
#import <BeatCore/BeatTagging.h>

@implementation BeatTextView (Tagging)

#pragma mark - Tagging

- (void)showTagSelector
{
	if (self.selectedRange.length == 0) return;
	
	NSString *selectedString = [self.string substringWithRange:self.selectedRange];
	
	// Don't allow line breaks in tagged content. Limit the selection if break is found.
	if ([selectedString containsString:@"\n"]) {
		[self setSelectedRange:(NSRange){ self.selectedRange.location, [selectedString rangeOfString:@"\n"].location }];
	}
	
	if (self.selectedRange.length < 1) return;
	
	// Add a new tag
	[self.popoverController displayWithRange:self.selectedRange items:BeatTagging.styledTags callback:^BOOL(NSString * _Nonnull string, NSInteger index) {
		// Tag string in the menu is prefixed by "● " or "× " so take them out
		NSString* tagStr = string;
		tagStr = [tagStr stringByReplacingOccurrencesOfString:@"× " withString:@""];
		tagStr = [tagStr stringByReplacingOccurrencesOfString:@"● " withString:@""];

		// String to be tagged
		NSString *tagString = [self.textStorage.string substringWithRange:self.selectedRange].lowercaseString;
		// Create a tag
		__block BeatTagType type = [BeatTagging tagFor:tagStr];
		
		// Check if a tag with given string and corresponding tag type already exists
		if (![self.tagging tagExists:tagString type:type]) {
			// If it doesn't exist, let's find possible similar tags. This method checks similarity between strings.
			NSArray *possibleMatches = [self.tagging searchTagsByTerm:tagString type:type];
			
			// If matches were found, display them in a new menu
			if (possibleMatches.count > 0) {
				// First object is reserved for creating a new tag
				NSArray *items = @[[NSString stringWithFormat:@"New: %@", tagString]];
				NSArray* matches = [items arrayByAddingObjectsFromArray:possibleMatches];
				
				// Display a new popover
				[self.popoverController displayWithRange:self.selectedRange items:matches callback:^BOOL(NSString * _Nonnull string, NSInteger index) {
					[self selectTagDefinition:string row:index type:type];
					return true;
				}];
				
				// Avoid closing the popover menu automatically
				self.popoverController.doNotClose = true;
				return true;
			}
		}

		// Tag the current range with newly created tag and deselect
		[self.tagging tagRange:self.selectedRange withType:type];
		self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
		
		return true;
	}];
}

- (void)selectTagDefinition:(NSString*)string row:(NSInteger)index type:(BeatTagType)type
{
	NSString* tagName;
	
	// First item is "CREATE A NEW TAG", while items after that are existing tags.
	if (index == 0) {
		tagName = [self.textStorage.string substringWithRange:self.selectedRange];
	} else {
		tagName = string;
	}
	
	TagDefinition* definition = [self.tagging definitionWithName:tagName type:type];
	
	if (definition) {
		// Definition was selected
		[self.tagging tagRange:self.selectedRange withDefinition:definition];
	} else {
		// Create new
		[self.tagging tagRange:self.selectedRange withType:type];
	}
	
	// Deselect
	self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
}



@end
