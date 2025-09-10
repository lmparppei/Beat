//
//  Document+SceneActions.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+SceneActions.h"
#import "Document+Scrolling.h"

@implementation Document (SceneActions)

#pragma mark - Moving between scenes and elements

- (IBAction)nextScene:(id)sender {
	Line* line = [self.parser nextOutlineItemOfType:heading from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}
- (IBAction)previousScene:(id)sender {
	Line* line = [self.parser previousOutlineItemOfType:heading from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)nextSection:(id)sender {
	Line* line = [self.parser nextOutlineItemOfType:section from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)previousSection:(id)sender {
	Line* line = [self.parser previousOutlineItemOfType:section from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)nextSectionOfSameDepth:(id)sender {
	Line* line = self.currentLine;
	if (line.type != section) {
		line = [self.parser previousOutlineItemOfType:section from:line.position];
	}
	
	line = [self.parser nextOutlineItemOfType:section from:line.position depth:line.sectionDepth];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)previousSectionOfSameDepth:(id)sender {
	Line* line = self.currentLine;
	if (line.type != section) {
		line = [self.parser previousOutlineItemOfType:section from:line.position];
	}
	
	Line * sectionLine = [self.parser previousOutlineItemOfType:section from:self.selectedRange.location depth:line.sectionDepth];
	if (sectionLine != nil) [self scrollToLine:sectionLine];
	else if (line != nil) [self scrollToLine:line];
}

- (IBAction)nextCharacterCue:(id)sender
{
	Line* line = self.currentLine;
	NSInteger i = [self.parser indexOfLine:line];
	if (line.isAnyCharacter) i++;
	
	while (i < self.parser.lines.count) {
		Line* l = self.parser.lines[i];
		if (l.isAnyCharacter) {
			[self selectAndScrollTo:NSMakeRange(l.position, 0)];
			break;
		}
		i++;
	}
}

- (IBAction)previousCharacterCue:(id)sender
{
	Line* line = self.currentLine;
	NSInteger i = [self.parser indexOfLine:line];
	if (line.isAnyCharacter) i--;
	
	while (i >= 0) {
		Line* l = self.parser.lines[i];
		if (l.isAnyCharacter) {
			[self scrollToRange:NSMakeRange(l.position, 0)];
			break;
		}
		i--;
	}
}

@end
