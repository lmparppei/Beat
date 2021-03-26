//
//  RecentFiles.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is the data source for welcome screen "recent files" outline view.
 I wrote this before I had any idea about how subclasses or delegates work,
 hence the silly class name etc.
 
*/

#import <Cocoa/Cocoa.h>
#import "RecentFiles.h"

#pragma mark - Recent files

@implementation RecentFiles

- (IBAction)doubleClickDocument:(id)sender {
	void (^completionHander)(NSDocument * _Nullable, BOOL, NSError * _Nullable) = ^void(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
	};
	
	[NSDocumentController.sharedDocumentController openDocumentWithContentsOfURL:_selectedRow display:YES completionHandler:completionHander];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	NSArray *files = [NSDocumentController.sharedDocumentController recentDocumentURLs];
	return [files count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	NSArray *array = [NSDocumentController.sharedDocumentController recentDocumentURLs];
	return [array objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	// Feast your eyes on the beauty of Objective-C!
	NSURL *fileUrl = item;
	NSDate *fileDate;
	NSError *error;
	NSString *date = @"";
		
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	paragraphStyle.lineSpacing = 1;
	
	NSArray *files = [NSDocumentController.sharedDocumentController recentDocumentURLs];
	
	bool selected = NO;
	if ([files indexOfObject:item] == outlineView.selectedRow) { selected = YES; }
	
	NSMutableAttributedString *fileResult = [[NSMutableAttributedString alloc] initWithString:[[item URLByDeletingPathExtension] lastPathComponent] attributes:@{
		NSParagraphStyleAttributeName: paragraphStyle,
		NSFontAttributeName: [NSFont systemFontOfSize:13.0]
	}];
	
	// Get file date
	[fileUrl getResourceValue:&fileDate forKey:NSURLContentModificationDateKey error:&error];
	if (!error) {
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[item path] error:&error];
		
		fileDate = (NSDate*)[attributes objectForKey: NSFileModificationDate];
		date = [NSDateFormatter localizedStringFromDate:fileDate
		dateStyle:NSDateFormatterShortStyle
		timeStyle:NSDateFormatterShortStyle];
	}
	
	NSColor *dateColor = NSColor.grayColor;
	if (selected) {
		dateColor = NSColor.lightGrayColor;
	}
	
	// Format date string
	NSMutableAttributedString *dateResult = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", date] attributes:@{
		NSParagraphStyleAttributeName: paragraphStyle,
		NSForegroundColorAttributeName: dateColor,
		NSFontAttributeName: [NSFont systemFontOfSize:10.0]
	}];

	[fileResult appendAttributedString:dateResult];
 
	return fileResult;
}

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
	
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	_selectedRow = item;
	return YES;
}

@end
