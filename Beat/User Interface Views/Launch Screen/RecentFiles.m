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
#ifndef QUICKLOOK
#import "Beat-Swift.h"
#endif

#pragma mark - Recent files

@interface RecentFiles()
@property (nonatomic) NSURL *selectedURL;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) NSArray *recentFiles;
@end

@implementation RecentFiles

-(void)awakeFromNib {
	if (_recentFiles.count == 0) _recentFiles = NSDocumentController.sharedDocumentController.recentDocumentURLs.copy;
}

- (instancetype)init{
	self = [super init];
	if (self) {
		_recentFiles = NSDocumentController.sharedDocumentController.recentDocumentURLs.copy;
	}
	return self;
}

- (void)reload
{
	// We'll cache the date results to avoid sandboxing file access problems.
	NSArray *files = _recentFiles;
	_items = NSMutableArray.new;

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
	
	if (_selectedURL == nil) return;
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
	
	BeatRecentFileCell *cell = [outlineView makeViewWithIdentifier:@"RecentFile" owner:self];
	cell.filename.stringValue = url.lastPathComponent.stringByDeletingPathExtension;
	cell.date.stringValue = date;
	
	return cell;
	
}

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
