//
//  BeatAboutScreen.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatDownloadManager.h"
#import "BeatPluginManager.h"

@interface BeatDownloadManager ()
@property (nonatomic) IBOutlet BeatPluginManager *pluginManager;
@end

@implementation BeatDownloadManager

- (instancetype)init {
	self = [super initWithWindowNibName:@"BeatDownloadManager" owner:self];
	
	if (self) {
		self.pluginView.dataSource = self.pluginManager;
	}
	
	return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];	
}
- (void)show {
	[self.window setFrame:NSMakeRect(
									 (NSScreen.mainScreen.frame.size.width - self.window.frame.size.width) / 2,
									 (NSScreen.mainScreen.frame.size.height - self.window.frame.size.height) / 2,
									 self.window.frame.size.width, self.window.frame.size.height
									 )
						 display:YES];
	
	[self.window setIsVisible:true];
	[self showWindow:self.window];
	[self.window makeKeyAndOrderFront:self];
	
	self.pluginView.dataSource = self.pluginManager;
	
	[self.pluginManager updateAvailablePlugins];
	[self.pluginManager getPluginLibraryWithCallback:^{
		// Reload again when external data has been loaded
		[self.pluginView reloadData];
	}];
	
	[self.pluginView reloadData];
}

@end
