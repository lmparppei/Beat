//
//  BeatOutlineView+Actions.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.10.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatOutlineView+Actions.h"
#import <BeatCore/BeatCore.h>
#import "Beat-Swift.h"

@implementation BeatOutlineView (Actions)

#pragma mark - Actions

- (IBAction)addSection:(id)sender
{
	if (self.clickedRow == -1 || self.clickedRow == NSNotFound) return;
	
	OutlineScene *scene = [self itemAtRow:self.clickedRow];
	if (scene != nil) {
		NSInteger pos = scene.position + scene.length;
		[self.editorDelegate.textActions addSection:pos];
	}
}

- (IBAction)setSceneColor:(id)sender
{
	if (self.clickedRow == -1 || self.clickedRow == NSNotFound) return;
	
	BeatColorMenuItem *item = sender;
	OutlineScene* selectedScene = [self itemAtRow:self.clickedRow];
	if (selectedScene != nil) [self.editorDelegate.textActions setColor:item.colorKey forScene:selectedScene];
}

@end
