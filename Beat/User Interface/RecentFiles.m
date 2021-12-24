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
#import "BeatRecentFileCell.h"

#pragma mark - Recent files

@interface RecentFiles()
@property (nonatomic) NSURL *selectedURL;
@property (nonatomic) NSMutableArray *items;
@end

@implementation RecentFiles

- (void)reload {
	// We'll cache the date results to avoid sandboxing file access problems.
	
	_items = [NSMutableArray array];
	
	NSArray *files = [NSDocumentController.sharedDocumentController recentDocumentURLs];

	for (NSURL *fileUrl in files) {
		NSDate *fileDate;
		NSError *error;
		NSString *date = @"";

		// Get file date
		[fileUrl getResourceValue:&fileDate forKey:NSURLContentModificationDateKey error:&error];
		if (!error) {
			NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:fileUrl.path error:&error];
			
			fileDate = (NSDate*)[attributes objectForKey: NSFileModificationDate];
			date = [NSDateFormatter localizedStringFromDate:fileDate
			dateStyle:NSDateFormatterShortStyle
			timeStyle:NSDateFormatterShortStyle];
		}
		
		[fileUrl.URLByDeletingLastPathComponent stopAccessingSecurityScopedResource];
		
		if (fileUrl && date) {
			[_items addObject:@{
				@"url": fileUrl,
				@"date": date
			}];
		}
	}
}

- (IBAction)doubleClickDocument:(id)sender {
	void (^completionHander)(NSDocument * _Nullable, BOOL, NSError * _Nullable) = ^void(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
	};
	
	[NSDocumentController.sharedDocumentController openDocumentWithContentsOfURL:_selectedURL display:YES completionHandler:completionHander];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	return _items.count;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	return _items[index];
}

- (NSView*)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSDictionary *fileItem = item;
	NSURL *url = fileItem[@"url"];
	NSString *date = fileItem[@"date"];
	
	BeatRecentFileCell* cell = [outlineView makeViewWithIdentifier:@"RecentFile" owner:self];
	cell.filename.stringValue = url.lastPathComponent.stringByDeletingPathExtension;
	cell.date.stringValue = date;
	
	return cell;
	
}
/*

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	bool selected = NO;
	if ([_items indexOfObject:item] == outlineView.selectedRow) selected = YES;

	 
	NSDictionary *fileItem = item;
	NSURL *url = fileItem[@"url"];
	NSString *date = fileItem[@"date"];

		
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	paragraphStyle.lineSpacing = 1;
			
	NSDictionary *fileAttributes = @{
		NSParagraphStyleAttributeName: paragraphStyle,
		NSFontAttributeName: [NSFont systemFontOfSize:13.0]
	};
	
	NSMutableAttributedString *fileResult = [[NSMutableAttributedString alloc] initWithString:url.URLByDeletingPathExtension.lastPathComponent attributes:fileAttributes];
	
	if (fileResult.size.width > outlineView.frame.size.width - 40) {
		NSInteger i = url.URLByDeletingPathExtension.lastPathComponent.length;
		while (fileResult.size.width > outlineView.frame.size.width - 40 && i > 0) {
			[fileResult setAttributedString:[fileResult attributedSubstringFromRange:(NSRange){0, i}]];
			[fileResult appendAttributedString:[[NSAttributedString alloc] initWithString:@"..." attributes:fileAttributes]];
			i--;
		}
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
*/

- (CGFloat)widthOfString:(NSString *)string withFont:(NSFont *)font {
	 NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
	 return [[NSAttributedString alloc] initWithString:string attributes:attributes].size.width;
 }

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
	
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	_selectedURL = item[@"url"];
	return YES;
}

@end
