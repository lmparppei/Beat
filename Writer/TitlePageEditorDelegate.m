//
//  TitlePageEditorDelegate.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18/10/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

//  wtf is this? (asking honestly after a year, doesn't seem to do anything meaningful)

#import "TitlePageEditorDelegate.h"

@implementation TitlePageEditorDelegate

/*
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
*/

- (bool) control: (NSControl*)control textView:(nonnull NSTextView *)textView doCommandBySelector:(nonnull SEL)commandSelector {
	BOOL result = NO;
	
	if (commandSelector == @selector(insertNewline:))
	{
		// Don't allow line break on single-line field
		if (control.lineBreakMode == NSLineBreakByClipping) return NO;
		
		// Else add line break
		[textView insertNewlineIgnoringFieldEditor:self];
		result = YES;
	}
	
	return result;
}

@end
