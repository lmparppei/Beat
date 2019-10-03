//
//  ApplicationDelegate.h
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Released under GPL license.

#import <Cocoa/Cocoa.h>

@interface ApplicationDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet NSWindow* _startModal;
	IBOutlet NSWindow* _aboutModal;
	IBOutlet NSOutlineView* recentFiles;
	IBOutlet NSTextField* versionField;
	
	IBOutlet NSTextField* aboutVersionField;
	IBOutlet NSTextView* aboutText;
}
@property (strong, nonatomic) NSWindow *_startModalWindow;
@property (strong, nonatomic) NSOutlineView *recentFiles;
@property (nonatomic) bool darkMode;
//@property (nonatomic) NSTextField * versionField;
- (IBAction)closeStartModal;
- (bool)isDark;
- (void)toggleDarkMode;
@end
