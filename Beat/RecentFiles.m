//
//  RecentFiles.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
	This is the data source for welcome screen "recent files" outline view.
*/

#import <Cocoa/Cocoa.h>
#import "RecentFiles.h"

#pragma mark - Recent files

@implementation DataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	NSArray *array = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
	return [array count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	NSArray *array = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
	return [array objectAtIndex:index];;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	return [item lastPathComponent];
}
- (IBAction)newDocument:(id)sender {
	[[NSDocumentController sharedDocumentController] newDocument:nil];
	//[_startModal close];
}

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
	
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	void (^completionHander)(NSDocument * _Nullable, BOOL, NSError * _Nullable) = ^void(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
	};
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:item display:YES completionHandler:completionHander];
	
	return YES;
}

// outlineView:numberOfChildrenOfItem:,
// outlineView:isItemExpandable:,
// outlineView:child:ofItem:
// outlineView:objectValueForTableColumn:byItem:


@end
