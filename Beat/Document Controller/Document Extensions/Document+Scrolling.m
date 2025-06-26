//
//  Document+Scrolling.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.6.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Scrolling.h"

@implementation Document (Scrolling)

- (void)scrollToSceneNumber:(NSString*)sceneNumber
{
	// Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
	OutlineScene *scene = [self.parser sceneWithNumber:sceneNumber];
	if (scene != nil) [self scrollToScene:scene];
}

- (void)scrollToScene:(OutlineScene*)scene
{
	[self selectAndScrollTo:scene.line.textRange];
	[self.documentWindow makeFirstResponder:self.textView];
}

/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range { [self selectAndScrollTo:range]; }

- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock
{
	[self.textView scrollToRange:range callback:callbackBlock];
}

/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location {
	NSRange range = NSMakeRange(location, 0);
	[self selectAndScrollTo:range];
}

/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line*)line
{
	if (line != nil) [self selectAndScrollTo:line.textRange];
}

/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index {
	Line *line = [self.parser.lines objectAtIndex:index];
	if (line != nil) [self selectAndScrollTo:line.textRange];
}

/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index
{
	OutlineScene *scene = [self.parser.outline objectAtIndex:index];
	if (!scene) return;
	
	NSRange range = NSMakeRange(scene.line.position, scene.string.length);
	[self selectAndScrollTo:range];
}

/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range
{
	[self.textView setSelectedRange:range];
	[self.textView scrollToRange:range callback:nil];
}

@end
