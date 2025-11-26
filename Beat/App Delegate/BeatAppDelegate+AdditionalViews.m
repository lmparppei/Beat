//
//  BeatAppDelegate+AdditionalViews.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+AdditionalViews.h"
#import "BeatAboutScreen.h"
#import "Beat-Swift.h"
#import "BeatPreferencesPanel.h"
#import "BeatEpisodePrinter.h"
#import "BeatPluginLibrary.h"
#import <StoreKit/StoreKit.h>

@implementation BeatAppDelegate (AdditionalViews)


#pragma mark - Menu items for showing screens. These should be view controllers.

- (IBAction)showAboutScreen:(id)sender
{
	if (!self.about) self.about = BeatAboutScreen.new;
	[self.about show];
}

- (IBAction)openPreferences:(id)sender
{
	if (!self.preferencesPanel) {
		self.preferencesPanel = BeatPreferencesPanel.new;
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.preferencesPanel.window];
	}
	[self.preferencesPanel show];
}

- (IBAction)openConsole:(id)sender
{
	[BeatConsole.shared openConsole];
}

/// I really should learn how to use window controllers
- (IBAction)printEpisodes:(id)sender
{
	if (!self.episodePrinter) {
		self.episodePrinter = BeatEpisodePrinter.new;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.episodePrinter.window];
	}
	
	[NSApp runModalForWindow:self.episodePrinter.window];
}



#pragma mark - App-wide Views

-(void)setupDocumentOpenListener
{
	// Let's close the welcome screen if any sort of document has been opened
	[NSNotificationCenter.defaultCenter addObserverForName:@"Document open" object:nil queue:nil usingBlock:^(NSNotification *note) {
		[self closeLaunchScreen];
	}];
	
	// Show modal if all documents were closed
	[NSNotificationCenter.defaultCenter addObserverForName:@"Document close" object:nil queue:nil usingBlock:^(NSNotification *note) {
		NSArray* openDocuments = NSApplication.sharedApplication.orderedDocuments;
		
		if (openDocuments.count == 0 && !self.welcomeWindow) {
			[self showLaunchScreen];
		}
		
#ifdef APPSTORE
		[self requestAppReview];
#endif
	}];
}

-(void)setupLaunchScreenIfNeeded
{
	if (self.launchWindowController == nil) {
		NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Launch Screen" bundle:NSBundle.mainBundle];
		self.launchWindowController = storyboard.instantiateInitialController;
	}
}

-(void)showLaunchScreen
{
	if (NSDocumentController.sharedDocumentController.documents.count > 0) return;

	[self setupLaunchScreenIfNeeded];
	
	[self.launchWindowController showWindow:self.launchWindowController.window];
}

-(void)showTemplates
{
	[self showLaunchScreenWithViewControllerName:@"Templates"];
}

- (void)showLaunchScreenWithViewControllerName:(NSString*)viewControllerName
{
	[self setupLaunchScreenIfNeeded];

	NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Launch Screen" bundle:NSBundle.mainBundle];
	NSViewController* vc = [storyboard instantiateControllerWithIdentifier:viewControllerName];
	self.launchWindowController.contentViewController = vc;
	
	[self.launchWindowController showWindow:self.launchWindowController.window];
}

- (void)closeLaunchScreen
{
	[self.launchWindowController close];
	self.launchWindowController = nil;
}

-(void)windowWillClose:(NSNotification *)notification
{
	// Dealloc window controllers on close
	NSWindow* window = notification.object;
	
	if (window == self.episodePrinter.window) {
		[NSApp stopModal];
		self.episodePrinter = nil;
	} else if (window == self.preferencesPanel.window) {
		self.preferencesPanel = nil;
	} else if (window == self.pluginLibrary.window) {
		[self.pluginLibrary clearWebView];
		self.pluginLibrary = nil;
	}
}

- (void)requestAppReview
{
	// The user has either clicked that they never want to review the app
	bool dontShowReviewPrompt = [NSUserDefaults.standardUserDefaults boolForKey:@"DontAskForReview"];
	if (dontShowReviewPrompt) return;
	
	// So, we'll see if the user has launched the app at least 50 times before requesting a review,
	// and _never_ again for the same version.
	NSInteger timesLaunched = [NSUserDefaults.standardUserDefaults integerForKey:@"LaunchCount"];
	NSString *lastVersionPrompted = [NSUserDefaults.standardUserDefaults valueForKey:@"LastVersionPromptedForReview"];
	NSString *currentVersion = [NSBundle.mainBundle.infoDictionary valueForKey:(NSString*)kCFBundleVersionKey];
	
	if (timesLaunched  % 51 == 50 && ![currentVersion isEqualToString:lastVersionPrompted]) {
		[NSUserDefaults.standardUserDefaults setValue:currentVersion forKey:@"LastVersionPromptedForReview"];
		
		if (@available(macOS 10.14, *)) [SKStoreReviewController requestReview];
	}
	
}

@end
