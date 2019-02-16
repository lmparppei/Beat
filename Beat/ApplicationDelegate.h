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
}
@property (strong, nonatomic) NSWindow *_startModalWindow;
- (IBAction)closeStartModal;
@end
