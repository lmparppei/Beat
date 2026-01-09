//
//  BeatTextView+CopyPaste.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 10.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+CopyPaste.h"
#import "BeatPasteboardItem.h"

@implementation BeatTextView (CopyPaste)

#pragma mark - Dragging

- (NSArray<NSPasteboardType>*)acceptableDragTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super acceptableDragTypes]];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:0];
	return types;
}

-(NSArray<NSPasteboardType>*)writablePasteboardTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super writablePasteboardTypes]];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:0];
	return types;
}

- (void)draggingEnded:(id<NSDraggingInfo>)sender
{
	NSPasteboard *pasteboard = [sender draggingPasteboard];
	NSArray<NSPasteboardType> *types = [pasteboard types];
	
	// If we've dragged a Beat pasteboard value, let's replace our selection with the correct attributed string.
	if ([types containsObject:BeatPasteboardItem.pasteboardType]) {
		BeatPasteboardItem *item = [pasteboard readObjectsForClasses:@[BeatPasteboardItem.class] options:nil][0];
		if (item.attrString != nil) {
			[self.textStorage replaceCharactersInRange:self.selectedRange withAttributedString:item.attrString];
		}
	}
}


#pragma mark - Copy-paste

- (NSAttributedString*)attributedStringForPasteboardFromRange:(NSRange)range
{
	// We create both a plaintext string & a custom pasteboard object
	NSMutableAttributedString* attrString = [self.attributedString attributedSubstringFromRange:range].mutableCopy;
	
	// Remove the represented line, because it can't be encoded
	if (attrString.length) [attrString removeAttribute:BeatRepresentedLineKey range:NSMakeRange(0, attrString.length)];
	
	return attrString;
}

-(void)copy:(id)sender
{
	NSPasteboard* pboard = NSPasteboard.generalPasteboard;
	[pboard clearContents];
	
	NSAttributedString* attrString = [self attributedStringForPasteboardFromRange:self.selectedRange];
	
	BeatPasteboardItem *item = [[BeatPasteboardItem alloc] initWithAttrString:attrString];
	[pboard writeObjects:@[item, attrString.string]];
}

-(NSArray<NSPasteboardType>*)readablePasteboardTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super readablePasteboardTypes]];
	// No idea why these are not available by default
	[types insertObject:@"public.rtf" atIndex:0];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:1];
	[types insertObject:@"public.utf16-plain-text" atIndex:2];
	[types insertObject:@"public.utf8-plain-text" atIndex:3];
	return types;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSPasteboardType)type
{
	if ([type isEqualToString:BeatPasteboardItem.pasteboardType]) {
		[pboard clearContents];
		
		// Get attributed string
		NSAttributedString* attrStr = [self attributedStringForPasteboardFromRange:self.selectedRange];
		
		BeatPasteboardItem* item = [BeatPasteboardItem.alloc initWithAttrString:attrStr];
		[pboard writeObjects:@[item]];
		return true;
	}
	
	return [super writeSelectionToPasteboard:pboard type:type];
}

-(void)paste:(id)sender
{
	[self paste:sender withoutFormatting:false];
}

- (IBAction)pasteWithoutFormatting:(id)sender
{
	[self paste:sender withoutFormatting:YES];
}

-(void)paste:(id)sender withoutFormatting:(bool)noFormatting
{
	NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
	NSArray<Class>* classes = @[BeatPasteboardItem.class, NSAttributedString.class, NSString.class];
		
	// See if we can read anything from the pasteboard
	if (![pasteboard canReadObjectForClasses:classes options:nil]) return;
		
	// We know for a fact that if the data originated from beat, the FIRST item will be
	// the custom object we created when copying. So let's just pick the first one of the
	// readable objects.
	
	NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classes options:@{}];
	id obj = objectsToPaste[0];
		
	if ([obj isKindOfClass:BeatPasteboardItem.class]) {
		// Paste custom Beat pasteboard data
		BeatPasteboardItem *pastedItem = obj;
		if (!noFormatting) {
			[self.editorDelegate.textActions replaceRange:self.selectedRange withAttributedString:pastedItem.attrString];
		} else {
			[self.editorDelegate.textActions replaceRange:self.selectedRange withString:pastedItem.attrString.string];
		}
	} else if ([obj isKindOfClass:NSAttributedString.class]) {
		// A basic attributed string. We have a category to convert basic inline styles to Fountain and account for spacing.
		NSAttributedString* attrStr = (NSAttributedString*)obj;
		NSString* result;
		if (!noFormatting) {
			result = attrStr.convertToFountain;
		} else {
			result = attrStr.string;
		}
		
		[self.editorDelegate.textActions replaceRange:self.selectedRange withString:result];
		
	} else if ([obj isKindOfClass:NSString.class]) {
		// Plain text
		NSString* result = (NSString*)obj;
		[self.editorDelegate.textActions replaceRange:self.selectedRange withString:result];
	} else {
		// If everything else fails, try normal paste
		[super paste:sender];
	}
		
	// If we didn't call super, the text view might not scroll back to caret
	[self scrollRangeToVisible:self.selectedRange];
}


@end
