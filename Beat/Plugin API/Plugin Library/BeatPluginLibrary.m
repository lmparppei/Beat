//
//  BeatPluginLibrary.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginLibrary.h"
#import "BeatPluginManager.h"
#import "BeatCheckboxCell.h"
#import "BeatColors.h"
#import "BeatAppDelegate.h"

@interface BeatPluginLibrary ()
@property (nonatomic) IBOutlet BeatPluginManager *pluginManager;
@property (nonatomic, weak) IBOutlet WKWebView *webview;
@end

@implementation BeatPluginLibrary

- (instancetype)init {
	self = [super initWithWindowNibName:@"BeatPluginLibrary" owner:self];
	
	if (self) {
		self.pluginView.dataSource = self.pluginManager;
		self.pluginView.delegate = self;
	}
	
	return self;
}

- (void)windowDidLoad {
	[super windowDidLoad];
}
- (void)clearWebView {
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"download"];
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openLink"];
	self.webview = nil;
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
	
	[self.webview.configuration.userContentController addScriptMessageHandler:self name:@"download"];
	[self.webview.configuration.userContentController addScriptMessageHandler:self name:@"openLink"];
	[self createPluginPageTemplate];
}

-(void)createPluginPageTemplate {
	NSURL *file = [NSBundle.mainBundle URLForResource:@"Plugin Page" withExtension:@"html"];
	NSString *page = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:nil];
	
	NSColor *updateColor = [BeatColors color:@"green"];
	NSColor *downloadColor = [BeatColors color:@"blue"];
	
	page = [page stringByReplacingOccurrencesOfString:@"#UPDATECOLOR#" withString:[NSString stringWithFormat:@"%f, %f, %f", updateColor.redComponent * 256, updateColor.greenComponent * 256, updateColor.blueComponent * 256]];
	page = [page stringByReplacingOccurrencesOfString:@"#DOWNLOADCOLOR#" withString:[NSString stringWithFormat:@"%f, %f, %f", downloadColor.redComponent * 256, downloadColor.greenComponent * 256, downloadColor.blueComponent * 256]];
	
	[self.webview loadHTMLString:page baseURL:self.pluginManager.pluginFolderURL];
}

- (NSString*)pluginJSON:(NSString*)pluginName {
	BeatPluginInfo *plugin = _pluginManager.availablePlugins[pluginName];
	NSData * data = [NSJSONSerialization dataWithJSONObject:plugin.json options:NSJSONWritingPrettyPrinted error:nil];
	NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return jsonString;
}
- (void)displayPluginPage:(NSString*)pluginName {
	NSString *jsonString = [self pluginJSON:pluginName];
	[_webview evaluateJavaScript:[NSString stringWithFormat:@"loadData(%@)", jsonString] completionHandler:nil];
}

#pragma mark - Outline View delegation

-(NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSInteger index = [self.pluginManager.availablePluginNames indexOfObject:(NSString*)item];
	
	NSString *name = self.pluginManager.availablePluginNames[index];
	BeatPluginInfo *pluginInfo = self.pluginManager.availablePlugins[name];
	
	BeatCheckboxCell* cell = [outlineView makeViewWithIdentifier:@"PluginCell" owner:self];
	
	cell.name = pluginInfo.name;
	
	// Set enabled state
	if ([self.pluginManager.disabledPlugins containsObject:name]) cell.enabled = NO; else cell.enabled = YES;
		
	// Set local url for installed plugins, nil it for others
	if (pluginInfo.installed) cell.localURL = pluginInfo.localURL;
	else cell.localURL = nil;
	
	// Set update info
	if (pluginInfo.updateAvailable) cell.updateAvailable = YES;
	else cell.updateAvailable = NO;
	
	return cell;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
	return YES;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
	return NO;
}
-(BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	return YES;
}
-(void)outlineViewSelectionDidChange:(NSNotification *)notification {
	id item = [_pluginView itemAtRow:_pluginView.selectedRow];
	[self displayPluginPage:item];
}

#pragma mark - Message handlers for WKWebView

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
	if ([message.name isEqualToString:@"download"]) {
		// Download request
		[_pluginManager downloadPlugin:message.body library:self withCallback:^(NSString * _Nonnull pluginName) {
			[self downloadComplete:pluginName];
		}];
	}
	else if ([message.name isEqualToString:@"openLink"]) {
		[(BeatAppDelegate*)NSApp.delegate openURLInWebBrowser:message.body];
	}
}

- (void)downloadComplete:(NSString*)pluginName {
	NSString *json = [self pluginJSON:pluginName];
	NSString *call = [NSString stringWithFormat:@"downloadComplete(%@)", json];
	[_webview evaluateJavaScript:call completionHandler:nil];

	[_pluginView reloadData];
	NSInteger selectedIndex = [_pluginView rowForItem:pluginName];
	[_pluginView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
}

@end
