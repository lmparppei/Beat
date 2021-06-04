//
//  BeatScriptParser.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 A fantasy side-project for creating a JavaScript scripting possibility for Beat.
 The idea is to expose the lines & scenes to JavaScript (via JSON) and let the user
 make what they want with them. The trouble is, though, that easily manipulating the
 screenplay via JS would require resetting the whole text content after it' done.
 
 Also, I want to make it possible to open a window/panel with custom HTML content to
 make it easier to build some weird analytics / statistics tools.
 
 */

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <WebKit/WebKit.h>
#import "BeatScriptParser.h"
#import "Line.h"
#import "OutlineScene.h"
#import "ApplicationDelegate.h"
#import "BeatPluginManager.h"
#import "BeatTagging.h"
#import "ApplicationDelegate.h"
#import "BeatPluginWindow.h"
#import <PDFKit/PDFKit.h>

@interface BeatScriptParser ()
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) WKWebView *sheetWebView;
@property (nonatomic) BeatPlugin *plugin;
@property (nonatomic, nullable) JSValue* updateMethod;
@property (nonatomic) bool resident;
@property (nonatomic) bool terminating;
@property (nonatomic) bool windowClosing;
@property (nonatomic) BeatPluginWindow *pluginWindow;
@end

@implementation BeatScriptParser

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
		
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];

	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Error Running Script";
		alert.informativeText = [NSString stringWithFormat:@"%@", exception];
		[alert addButtonWithTitle:@"OK"];
		[alert runModal];
	}];

	[_context setObject:[Line class] forKeyedSubscript:@"Line"];
	[_context setObject:[OutlineScene class] forKeyedSubscript:@"OutlineScene"];
	[_context setObject:self forKeyedSubscript:@"Beat"];
	
	return self;
}

#pragma mark - Running Scripts

- (void)runPlugin:(BeatPlugin*)plugin
{
	self.plugin = plugin;
	_pluginName = plugin.name;
	
	[BeatPluginManager.sharedManager pathForPlugin:plugin.name];
	
	[self runScript:plugin.script];
}

- (void)runScript:(NSString*)string
{
	[self setJSData];
	
	[_context evaluateScript:string];

	// Kill it if the plugin is not resident
	if (!self.sheet && !_resident && !_pluginWindow) {
		[self endScript];
	}
}

- (void)end { [self endScript]; } // Alias
- (void)endScript
{
	_terminating = YES;

	if (!_windowClosing && _pluginWindow) {
		[_pluginWindow close];
	}
		
	// Null everything
	_context = nil;
	_vm = nil;
	_sheet = nil;
	_sheetCallback = nil;
	_plugin = nil;
	
	//_updateMethod = nil;
	
	if (_resident) {
		[_delegate deregisterPlugin:self];
	}

}

- (void)openConsole {
	[(ApplicationDelegate*)NSApp.delegate openConsole];
}
- (IBAction)clearConsole:(id)sender {
	[(ApplicationDelegate*)NSApp.delegate clearConsole];
}

/*
if ([fileManager fileExistsAtPath:filepath isDirectory:YES]) {
	
} else {
	[plugins addObject:filepath];
}
*/


#pragma mark - Resident plugin

- (void)setUpdate:(JSValue *)updateMethod {
	// Save callback
	_updateMethod = updateMethod;
	_resident = YES;
	
	// Tell the delegate to keep this plugin in memory and update it on refresh
	[_delegate registerPlugin:self];
}
- (void)update:(NSRange)range {
	[_updateMethod callWithArguments:@[@(range.location), @(range.length)]];
}

#pragma mark - File i/o

- (void)saveFile:(NSString*)format callback:(JSValue*)callback
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.allowedFileTypes = @[format];
	[savePanel beginSheetModalForWindow:self.delegate.thisWindow completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[savePanel close];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
				[callback callWithArguments:@[savePanel.URL.path]];
			});
		} else {
			[callback callWithArguments:nil];
		}
	}];
}
- (bool)writeToFile:(NSString*)path content:(NSString*)content
{
	NSError *error;
	[content writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:&error];
	
	if (error) {
		[self alert:@"Error Writing File" withText:[NSString stringWithFormat:@"%@", error]];
		return NO;
	} else {
		return YES;
	}
}

- (void)openFile:(NSArray*)formats callBack:(JSValue*)callback
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = formats;
	[openPanel beginSheetModalForWindow:self.delegate.thisWindow completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[openPanel close];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
				// some other method calls here
				[callback callWithArguments:@[openPanel.URL.path]];
			});
		} else {
			[callback callWithArguments:nil];
		}
	}];
}

- (NSString*)fileToString:(NSString*)path
{
	NSError *error;
	NSString *result = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	if (error) {
		[self alert:@"Error Opening File" withText:@"Error occurred while trying to open the file. Did you give Beat permission to acces it?"];
		return nil;
	} else {
		return result;
	}
}

- (NSString*)pdfToString:(NSString*)path
{
	NSMutableString *result = [NSMutableString string];
	
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
	if (!doc) return @"";
	
	for (int i = 0; i < doc.pageCount; i++) {
		PDFPage *page = [doc pageAtIndex:i];
		if (!page) continue;
		
		[result appendString:page.string];
	}
	
	return result;
}

- (NSString*)assetAsString:(NSString *)filename
{
	if ([_plugin.files containsObject:filename]) {
		NSString *path = [[BeatPluginManager.sharedManager pathForPlugin:_plugin.name] stringByAppendingPathComponent:filename];
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	} else {
		[self log:@"Can't find bundled file '%@' – Are you sure the plugin is contained in a self-titled folder? For example: Plugin.beatPlugin/Plugin.beatPlugin"];
		return @"";
	}
	
}

#pragma mark - Scripting methods accessible via JS

- (void)log:(NSString*)string
{
	[(ApplicationDelegate*)NSApp.delegate logToConsole:string pluginName:_pluginName];
	NSLog(@"%@: %@", _pluginName, string);
}

- (void)scrollTo:(NSInteger)location
{
	[self.delegate scrollTo:location];
}

- (void)scrollToLine:(Line*)line
{
	@try {
		[_delegate scrollToLine:line];
	}
	@catch (NSException *e) {
		[self alert:@"Can't find line" withText:@"Plugin tried to access an unknown line"];
	}
}
- (void)scrollToLineIndex:(NSInteger)index
{
	[self.delegate scrollToLineIndex:index];
}

- (void)scrollToSceneIndex:(NSInteger)index
{
	[self.delegate scrollToSceneIndex:index];
}

- (void)scrollToScene:(OutlineScene*)scene
{
	@try {
		[self.delegate scrollToScene:scene];
	}
	@catch (NSException *e) {
		[self alert:@"Can't find scene" withText:@"Plugin tried to access an unknown scene"];
	}
}

- (void)addString:(NSString*)string toIndex:(NSUInteger)index
{
	[self.delegate addString:string atIndex:index];
}

- (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string
{
	NSRange range = NSMakeRange(from, length);
	@try {
		[self.delegate replaceRange:range withString:string];
	}
	@catch (NSException *e) {
		[self alert:@"Selection out of range" withText:@"Plugin tried to select something that was out of range. Further errors might ensue."];
	}
}

- (NSRange)selectedRange
{
	return self.delegate.selectedRange;
}

- (void)setSelectedRange:(NSInteger)start to:(NSInteger)length
{
	NSRange range = NSMakeRange(start, length);
	[self.delegate setSelectedRange:range];
}

- (NSString*)getText
{
	return [_delegate getText];
}

- (void)alert:(NSString*)title withText:(NSString*)info
{
	if ([info isEqualToString:@"undefined"]) info = @"";
	
	NSAlert *alert = [self dialog:title withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert runModal];
}

- (bool)confirm:(NSString*)title withInfo:(NSString*)info
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		return YES;
	} else {
		return NO;
	}
}

- (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText
{
	if ([placeholder isEqualToString:@"undefined"]) placeholder = @"";
	if ([defaultText isEqualToString:@"undefined"]) defaultText = @"";
	
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSRect frame = NSMakeRect(0, 0, 300, 24);
	NSTextField *inputField = [[NSTextField alloc] initWithFrame:frame];
	inputField.placeholderString = placeholder;
	[alert setAccessoryView:inputField];
	[inputField setStringValue:defaultText];
	
	alert.window.initialFirstResponder = inputField;
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		return inputField.stringValue;
	} else {
		return nil;
	}
}

- (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items
{
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0, 300, 24)];
	
	[popup addItemWithTitle:@"Select..."];
	
	for (id item in items) {
		// Make sure the title becomes a string
		NSString *title = [NSString stringWithFormat:@"%@", item];
		[popup addItemWithTitle:title];
	}
	[alert setAccessoryView:popup];
	NSModalResponse response = [alert runModal];
	
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		// Return an empty string if the user didn't select anything
		if ([popup.selectedItem.title isEqualToString:@"Select..."]) return @"";
		else return popup.selectedItem.title;
	} else {
		return nil;
	}
}

- (NSAlert*)dialog:(NSString*)title withInfo:(NSString*)info
{
	if ([info isEqualToString:@"undefined"]) info = @"";

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	return alert;
}

- (void)setUserDefault:(NSString*)settingName setting:(id)value
{
	if (!_pluginName) {
		[self alert:@"No plugin name" withText:@"You need to specify plugin name before trying to save settings."];
		return;
	}
	
	NSString *keyName = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	[[NSUserDefaults standardUserDefaults] setValue:value forKey:keyName];
}

- (id)getUserDefault:(NSString*)settingName
{
	NSString *keyName = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	id value = [[NSUserDefaults standardUserDefaults] valueForKey:keyName];
	return value;
}

#pragma mark - Timer

- (NSTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback {
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:seconds repeats:NO block:^(NSTimer * _Nonnull timer) {
		[callback callWithArguments:nil];
	}];
	return timer;
}

#pragma mark - HTML panel magic

/*
 
 These two should be merged at some point
 
 */

- (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
	if (_delegate.thisWindow.attachedSheet) return;
	
	if (width <= 0) width = 600;
	if (width > 800) width = 1000;
	if (height <= 0) height = 400;
	if (height > 800) height = 1000;
	
	// Load template
	NSURL *templateURL = [NSBundle.mainBundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	NSWindow *panel = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0, width, height + 35) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	
	WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 35, width, height)];
	[webView loadHTMLString:template baseURL:nil];
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"sendData"];
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"log"];
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"call"];
	[panel.contentView addSubview:webView];
	
	NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 90, 5, 90, 24)];
	okButton.bezelStyle = NSRoundedBezelStyle;
	[okButton setButtonType:NSMomentaryLightButton];
	[okButton setTarget:self];
	[okButton setAction:@selector(fetchHTMLPanelDataAndClose)];

	// Make esc close the panel
	okButton.keyEquivalent = [NSString stringWithFormat:@"%C", 0x1b];
	okButton.title = @"Close";
	[panel.contentView addSubview:okButton];
	
	// Add cancel button if needed
	if (cancelButton) {
		NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 175, 5, 90, 24)];
		cancelButton.bezelStyle = NSRoundedBezelStyle;
		[cancelButton setButtonType:NSMomentaryLightButton];
		[cancelButton setTarget:self];
		[cancelButton setAction:@selector(closePanel:)];

		// Close button is now OK and enter is the shortcut for sending the data
		okButton.title = @"OK";
		okButton.keyEquivalent = @"\r";
		
		// Esc closes the panel
		cancelButton.keyEquivalent = [NSString stringWithFormat:@"%C", 0x1b];
		cancelButton.title = @"Cancel";
		[panel.contentView addSubview:cancelButton];
	}
	
	_sheet = panel;
	_sheetWebView = webView;
	_sheetCallback = callback;
	
	[self.delegate.thisWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"sendData"];
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"log"];
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"call"];
		self.sheetWebView = nil;
		self.sheet = nil;
	}];
}

- (void)fetchHTMLPanelDataAndClose
{
	[_sheetWebView evaluateJavaScript:@"sendBeatData();" completionHandler:nil];
	
	// The sheet will close automatically after that, but run an alert if the sheet didn't close in time
	// (for both the developer and the user to understand that something isn't working right)
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 2), dispatch_get_main_queue(), ^(void){
		if (self.delegate.thisWindow.attachedSheet == self.sheet && self.delegate.thisWindow.attachedSheet != nil) {
			[self alert:@"Plugin timed out" withText:@"Something went wrong with receiving data from the plugin"];
			[self closePanel:nil];
		}
	});
}

- (void)closePanel:(id)sender
{
	if (self.delegate.thisWindow.attachedSheet) {
		[self.delegate.thisWindow endSheet:_sheet];
	}
}

- (void)receiveDataFromHTMLPanel:(NSString*)json
{
	// This method actually closes the HTML panel.
	// It is called by sending a message to the script parser via webkit message handler,
	// so this works asynchronously. Keep in mind.
	
	if ([json isEqualToString:@"(null)"]) json = @"";
	
	if (self.sheetCallback) {
		NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
		NSError *error;
		NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
		
		if (!error) {
			[self closePanel:nil];
			[_sheetCallback callWithArguments:@[jsonData]];
		}
		else {
			[self closePanel:nil];
			[self alert:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
		}
		
		_sheetCallback = nil;
	} else {
		// If there was no callback, it marks the end of the script
		[self closePanel:nil];
		_context = nil;
		_vm = nil;
	}
}

#pragma mark - HTML Window

- (BeatPluginWindow*)htmlWindow:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback
{
	// This is a floating window, so the plugin has to be resident
	_resident = YES;
	_windowClosing = NO;
	
	if (width <= 0) width = 500;
	if (width > 1000) width = 1000;
	if (height <= 0) height = 300;
	if (height > 800) height = 800;
		
	if (!_pluginWindow) {
		[_delegate registerPlugin:self];
		_pluginWindow = [BeatPluginWindow withHTML:html width:width height:height parser:self];
		_pluginWindow.parentWindow = _delegate.thisWindow;
		_pluginWindow.delegate = self;
		[_pluginWindow makeKeyAndOrderFront:nil];
	}
	
	if (callback && !callback.isUndefined) _windowCallback = callback;
	
	return _pluginWindow;
}

-(void)windowWillClose:(NSNotification *)notification {
	NSLog(@"window will close");
	_windowClosing = YES;

	// Remove webview from memory, for sure
	[_pluginWindow.webview.configuration.userContentController removeScriptMessageHandlerForName:@"sendData"];
	[_pluginWindow.webview.configuration.userContentController removeScriptMessageHandlerForName:@"call"];
	[_pluginWindow.webview.configuration.userContentController removeScriptMessageHandlerForName:@"log"];
	_pluginWindow.webview = nil;
	

	if (_terminating) return;
	
	if (!_windowCallback.isUndefined && _windowCallback) {
		NSLog(@"Callback");
		[_windowCallback callWithArguments:nil];
	}
//	else {
//		NSLog(@"Force end script");
//		[self end];
//	}

	_windowClosing = NO;
}


#pragma mark - Tagging interface

- (NSArray*)availableTags {
	return [BeatTagging tags];
}
- (NSDictionary*)tagsForScene:(OutlineScene *)scene
{
	return [self.delegate.tagging tagsForScene:scene];
}

#pragma mark - Utilities

- (NSArray*)screen {
	NSRect screen = self.delegate.thisWindow.screen.frame;
	return @[ @(screen.origin.x), @(screen.origin.y), @(screen.size.width), @(screen.size.height) ];
}

#pragma mark - Parser data delegation

- (NSArray*)lines
{
	return self.delegate.parser.lines;
}
- (NSArray*)linesForScene:(id)sceneId
{
	NSMutableArray *lines = [NSMutableArray array];
	OutlineScene *scene = (OutlineScene*)sceneId;
	
	@try {
		NSRange sceneRange = NSMakeRange(scene.sceneStart, scene.sceneLength);
		
		for (Line* line in self.delegate.parser.lines) {
			if (NSLocationInRange(line.position, sceneRange)) [lines addObject:line];
		}
	}
	@catch (NSException *e) {
		[self alert:@"Scene index out of range" withText:@"Plugin tried to access an nonexistent scene"];
	}
	return lines;
}

- (NSArray*)scenes
{
	[self.delegate.parser createOutline];
	return self.delegate.parser.scenes;
}

- (NSArray*)outline
{
	[self.delegate.parser createOutline];
	return self.delegate.parser.outline;
}

- (void)parse
{
	[self.delegate.parser createOutline];
	[self setJSData];
}

- (void)newDocument:(NSString*)string
{
	if (string.length) [(ApplicationDelegate*)NSApp.delegate newDocumentWithContents:string];
	else [[NSDocumentController sharedDocumentController] newDocument:nil];
}

- (void)setJSData
{
	[_context setObject:self.delegate.parser.lines forKeyedSubscript:@"Lines"];
	[_context setObject:self.delegate.parser.outline forKeyedSubscript:@"Outline"];
	[_context setObject:self.delegate.parser.scenes forKeyedSubscript:@"Scenes"];
}


- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
	if ([message.name isEqualToString:@"log"]) {
		[self log:message.body];
	}
	else if ([message.name isEqualToString:@"sendData"]) {
		if (!_windowClosing) [self receiveDataFromHTMLPanel:message.body];
	}
	else if ([message.name isEqualToString:@"call"]) {
		NSLog(@"calling: %@", message.body);
		if (!_windowClosing) [_context evaluateScript:message.body];
	}
}

@end
/*

 No one is thinking about the flowers
 no one is thinking about the fish
 no one wants
 to believe that the garden is dying
 
 */
