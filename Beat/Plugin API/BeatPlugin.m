//
//  BeatPlugin.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020-2021 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 This class provides JavaScript API for plugins.
 
 One parser is created for one plugin. It has its own JSContext, and plugins
 can open windows, set up timers and even show widgets.
 
 Plugin manager provides a BeatPluginData object which contains
 plugin name and URL. A plugin is then initialized using that data.
 
 
 */

#import "BeatPlugin.h"
#import <objc/runtime.h>

@interface BeatPlugin ()
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) WKWebView *sheetWebView;
@property (nonatomic) BeatPluginData *plugin;
@property (nonatomic) NSMutableArray *timers;
@property (nonatomic) NSMutableArray *speakSynths;
@property (nonatomic, nullable) JSValue* updateMethod;
@property (nonatomic, nullable) JSValue* updateSelectionMethod;
@property (nonatomic, nullable) JSValue* updateOutlineMethod;
@property (nonatomic, nullable) JSValue* updateSceneMethod;
@property (nonatomic) bool resident;
@property (nonatomic) bool terminating;
@property (nonatomic) bool windowClosing;
@property (nonatomic) bool inCallback;
@property (nonatomic) bool terminateAfterCallback;
@property (nonatomic) NSMutableArray *pluginWindows;
@property (nonatomic) NSDictionary *type;
@property (nonatomic) WebPrinter *printer;
@property (nonatomic) BeatPluginUIView *widgetView;
@end

@implementation BeatPlugin

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
		
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];

	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		if (NSThread.isMainThread) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Error Running Script";
			alert.informativeText = [NSString stringWithFormat:@"%@", exception];
			[alert addButtonWithTitle:@"OK"];
			[alert runModal];
		} else {
			NSString *errMsg = [NSString stringWithFormat:@"Error: %@", exception];
			[(BeatAppDelegate*)NSApp.delegate logToConsole:errMsg pluginName:@"Plugin parser"];
		}
	}];
		
	[_context setObject:self forKeyedSubscript:@"Beat"];
	
	return self;
}

#pragma mark - Running Scripts

- (void)loadPlugin:(BeatPluginData*)plugin
{
	self.plugin = plugin;
	_pluginName = plugin.name;
	
	[BeatPluginManager.sharedManager pathForPlugin:plugin.name];
	
	[self runScript:plugin.script];
}

- (void)runScript:(NSString*)string
{
	[self.context evaluateScript:string];

	// Kill it if the plugin is not resident
	if (!self.sheet && !self.resident && self.pluginWindows.count < 1 && !self.widgetView) {
		[self end];
	}
}

- (void)forceEnd {
	// This is user for force-quitting a resident plugin from the tools menu
	
	_terminating = YES;
	if (_pluginWindows.count) {
		for (BeatPluginHTMLWindow *window in _pluginWindows) {
			[window closeWindow];
		}
	}
	
	// Remove widget
	if (_widgetView != nil) [_widgetView remove];
	
	_sheet = nil;
	_sheetCallback = nil;
	_plugin = nil;
	
	[self stopBackgroundInstances];
	[_delegate deregisterPlugin:self];
}

- (void)end {
	// If end was called in callback, we'll wait until it's done before killing the plugin altogether
	if (_inCallback) {
		_terminateAfterCallback = YES;
		return;
	}
	
	_terminating = YES;
	
	if (_pluginWindows.count) {
		for (BeatPluginHTMLWindow *window in _pluginWindows) {
			// Don't perform any callbacks here
			if (window.isVisible && !window.isClosing) {
				[window closeWindow];
			}
		}
	}
	
	// Stop any timers left
	[self stopBackgroundInstances];
	
	// Remove widget
	if (_widgetView != nil) [_widgetView remove];
	
	//_vm = nil;
	_sheet = nil;
	_sheetCallback = nil;
	_plugin = nil;
	
	if (_resident) {
		[_delegate deregisterPlugin:self];
	}
}

- (void)focusEditor {
	// Give focus back to the editor
	[_delegate focusEditor];
}

- (void)openConsole {
	[(BeatAppDelegate*)NSApp.delegate openConsole];
}
- (IBAction)clearConsole:(id)sender {
	[(BeatAppDelegate*)NSApp.delegate clearConsole];
}

- (bool)compatibleWith:(NSString *)version {
	return [BeatPluginManager.sharedManager isCompatible:version];
}

#pragma mark - Resident plugin

// Text change update
- (void)onTextChange:(JSValue*)updateMethod {
	[self setUpdate:updateMethod];
}
- (void)setUpdate:(JSValue *)updateMethod {
	// Save callback
	_updateMethod = updateMethod;
	_resident = YES;
	
	// Tell the delegate to keep this plugin in memory and update it on refresh
	[_delegate registerPlugin:self];
}
- (void)update:(NSRange)range {
	if (!_updateMethod || [_updateMethod isNull]) return;
	if (!self.onTextChangeDisabled) [_updateMethod callWithArguments:@[@(range.location), @(range.length)]];
}

// Selection change update
- (void)onSelectionChange:(JSValue*)updateMethod {
	[self setSelectionUpdate:updateMethod];
}
- (void)setSelectionUpdate:(JSValue *)updateMethod {
	// Save callback for selection change update
	_updateSelectionMethod = updateMethod;
	_resident = YES;
	
	// Tell the delegate to keep this plugin in memory and update it on refresh
	[_delegate registerPlugin:self];
}
- (void)updateSelection:(NSRange)selection {
	if (!_updateSelectionMethod || [_updateSelectionMethod isNull]) return;
	if (!self.onSelectionChangeDisabled) [_updateSelectionMethod callWithArguments:@[@(selection.location), @(selection.length)]];
}

// Outline change update
- (void)onOutlineChange:(JSValue*)updateMethod {
	[self setOutlineUpdate:updateMethod];
}
- (void)setOutlineUpdate:(JSValue *)updateMethod {
	// Save callback for selection change update
	_updateOutlineMethod = updateMethod;
	_resident = YES;
	
	// Tell the delegate to keep this plugin in memory and update it on refresh
	[_delegate registerPlugin:self];
}
- (void)updateOutline:(NSArray*)outline {
	if (!_updateOutlineMethod || [_updateOutlineMethod isNull]) {
		return;
	}
	
	if (!self.onOutlineChangeDisabled) [_updateOutlineMethod callWithArguments:self.delegate.parser.outline];
}

- (void)onSceneIndexUpdate:(JSValue*)updateMethod {
	[self setSceneIndexUpdate:updateMethod];
}
- (void)setSceneIndexUpdate:(JSValue*)updateMethod {
	// Save callback for selection change update
	_updateSceneMethod = updateMethod;
	_resident = YES;
	
	// Tell the delegate to keep this plugin in memory and update it on refresh
	[_delegate registerPlugin:self];
}
- (void)updateSceneIndex:(NSInteger)sceneIndex {
	if (!self.onSceneIndexUpdateDisabled) [_updateSceneMethod callWithArguments:@[@(sceneIndex)]];
}

#pragma mark - Multithreading

- (void)async:(JSValue*)callback {
	[self dispatch:callback];
}
- (void)sync:(JSValue*)callback {
	[self dispatch_sync:callback];
}
- (void)dispatch:(JSValue*)callback {
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		[callback callWithArguments:nil];
	});
}
- (void)dispatch_sync:(JSValue*)callback {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[callback callWithArguments:nil];
	});
}

- (JSValue*)fetch:(JSValue*)callback {
	return nil;
}

#pragma mark - Speak

- (BeatSpeak*)speakSynth {
	if (!_speakSynths) _speakSynths = NSMutableArray.new;	
	
	BeatSpeak *synth = BeatSpeak.new;
	[_speakSynths addObject:synth];
	
	return synth;
}

#pragma mark - Timer

- (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats {
	BeatPluginTimer *timer = [BeatPluginTimer scheduledTimerWithTimeInterval:seconds repeats:repeats block:^(NSTimer * _Nonnull timer) {
		[self runCallback:callback withArguments:nil];
	}];
	
	// When adding a new timer, remove references to invalid ones
	[self cleanInvalidTimers];
	
	// Add the new timer to timer array
	if (!_timers) _timers = [NSMutableArray array];
	[_timers addObject:timer];
		
	return timer;
}
- (void)cleanInvalidTimers {
	NSMutableArray *timers = [NSMutableArray array];
	
	for (int i=0; i < _timers.count; i++) {
		BeatPluginTimer *timer = _timers[i];
		if (timer.isValid) [timers addObject:timer];
	}
	
	_timers = timers;
}
- (void)stopBackgroundInstances {
	for (BeatPluginTimer *timer in _timers) {
		[timer invalidate];
	}
	[_timers removeAllObjects];
	_timers = nil;
	
	for (BeatSpeak *synth in _speakSynths) {
		[synth stopSpeaking];
	}
	[_speakSynths removeAllObjects];
	_speakSynths = nil;
}


#pragma mark - File i/o

- (void)saveFile:(NSString*)format callback:(JSValue*)callback
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.allowedFileTypes = @[format];
	[savePanel beginSheetModalForWindow:self.delegate.documentWindow completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[savePanel close];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
				[callback callWithArguments:@[savePanel.URL.path]];
			});
		} else {
			
			[self runCallback:callback withArguments:nil];
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
	
	NSModalResponse result = [openPanel runModal];
	if (result == NSModalResponseOK) {
		[self runCallback:callback withArguments:@[openPanel.URL.path]];
	} else {
		[self runCallback:callback withArguments:nil];
	}
	
	/*
	 // Alternatively we can use a sheet
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
	*/
}

- (void)openFiles:(NSArray*)formats callBack:(JSValue*)callback
{
	// Open MULTIPLE files
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = formats;
	openPanel.allowsMultipleSelection = YES;
	
	NSModalResponse result = [openPanel runModal];
	
	if (result == NSModalResponseOK) {
		NSMutableArray *paths = [NSMutableArray array];
		for (NSURL* url in openPanel.URLs) {
			[paths addObject:url.path];
		}
		[self runCallback:callback withArguments:@[paths]];
	} else {
		[self runCallback:callback withArguments:nil];
	}
	
	/*
	// Alternatively we can use a sheet
	[openPanel beginSheetModalForWindow:self.delegate.thisWindow completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[openPanel close];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
				// some other method calls here
				NSMutableArray *paths = [NSMutableArray array];
				for (NSURL* url in openPanel.URLs) {
					[paths addObject:url.path];
				}
				
				[callback callWithArguments:@[paths]];
			});
		} else {
			[callback callWithArguments:nil];
		}
	}];
	*/
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

- (NSString*)appAssetAsString:(NSString *)filename
{
	NSString *path = [NSBundle.mainBundle pathForResource:filename.stringByDeletingPathExtension ofType:filename.pathExtension];
	
	if (path) {
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	} else {
		[self log:@"Can't find bundled file '%@' from app bundle"];
		return @"";
	}
}


#pragma mark - Scripting methods accessible via JS

- (void)log:(NSString*)string
{
	[(BeatAppDelegate*)NSApp.delegate logToConsole:string pluginName:_pluginName];
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
		[self reportError:@"Plugin tried to access an unknown line" withText:line.string];
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
		[self reportError:@"Can't find scene" withText:@"Plugin tried to access an unknown scene"];
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
		[self reportError:@"Selection out of range" withText:@"Plugin tried to select something that was out of range. Further errors might ensue."];
	}
}

- (NSRange)selectedRange
{
	return self.delegate.selectedRange;
}

- (void)setSelectedRange:(NSInteger)start to:(NSInteger)length
{
	@try {
		NSRange range = NSMakeRange(start, length);
		[self.delegate setSelectedRange:range];
	}
	@catch (NSException *exception) {
		[self reportError:@"Out of range" withText:[NSString stringWithFormat:@"position: %lu  length: %lu", start, length]];
	}
}

- (NSString*)getText
{
	return _delegate.text;
}

- (void)reportError:(NSString*)title withText:(NSString*)string {
	// In the main thread, display errors as a modal window
	if (NSThread.isMainThread) [self alert:title withText:string];
	// Inn a background thread errors are logged to console
	else [self log:[NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string]];
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

- (NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback {
	// We support both return & callback in modal windows
	
	NSString *title = (settings[@"title"]) ? settings[@"title"] : @"";
	NSString *info  = (settings[@"info"]) ? settings[@"info"] : @"";
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	BeatModalAccessoryView *itemView = [[BeatModalAccessoryView alloc] init];
	
	if ([settings[@"items"] isKindOfClass:NSArray.class]) {
		NSArray *items = settings[@"items"];
		
		for (NSDictionary* item in items) {
			[itemView addField:item];
		}
	}
	
	[itemView setFrame:(NSRect){ 0, 0, 350, itemView.heightForItems }];
	[alert setAccessoryView:itemView];
	NSModalResponse response = [alert runModal];
	
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		NSDictionary *values = itemView.valuesForFields;
		[self runCallback:callback withArguments:@[values]];
		return values;
	} else {
		[self runCallback:callback withArguments:nil];
		return nil;
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
		[self reportError:@"setUserDefault: No plugin name" withText:@"You need to specify plugin name before trying to save settings."];
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
		[self runCallback:callback withArguments:nil];
	}];
	return timer;
}

#pragma mark - HTML panel magic

/*
 
 These two should be merged at some point
 
 */

- (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
	if (_delegate.documentWindow.attachedSheet) return;
	
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
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"callAndLog"];
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
	
	[self.delegate.documentWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"sendData"];
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"log"];
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"call"];
		[webView.configuration.userContentController removeScriptMessageHandlerForName:@"callAndLog"];
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
		if (self.delegate.documentWindow.attachedSheet == self.sheet && self.delegate.documentWindow.attachedSheet != nil) {
			[self reportError:@"Plugin timed out" withText:@"Something went wrong with receiving data from the plugin"];
			[self closePanel:nil];
		}
	});
}

- (void)closePanel:(id)sender
{
	if (self.delegate.documentWindow.attachedSheet) {
		[self.delegate.documentWindow endSheet:_sheet];
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
			[self runCallback:self.sheetCallback withArguments:@[jsonData]];
		} else {
			[self closePanel:nil];
			[self reportError:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
		}
		
		_sheetCallback = nil;
	} else {
		// If there was no callback, it marks the end of the script
		[self closePanel:nil];
		_context = nil;
	}
}

#pragma mark - Window management

- (void)gangWithDocumentWindow:(NSWindow*)window {
	[self.delegate.documentWindow addChildWindow:window ordered:NSWindowAbove];
}
- (void)detachFromDocumentWindow:(NSWindow*)window {
	[self.delegate.documentWindow removeChildWindow:window];
}

- (void)showAllWindows {
	if (_terminating) return;
	
	for (NSWindow *window in self.pluginWindows) {
		window.level = NSFloatingWindowLevel;

		//[window setIsVisible:YES];
	}
}
- (void)hideAllWindows {
	if (_terminating) return;
	
	for (NSWindow *window in self.pluginWindows) {
		window.level = NSNormalWindowLevel;
		//[window setIsVisible:NO];
	}
}

#pragma mark - HTML Window

- (BeatPluginHTMLWindow*)htmlWindow:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback
{
	// This is a floating window, so the plugin has to be resident
	_resident = YES;
	
	if (width <= 0) width = 500;
	if (width > 1000) width = 1000;
	if (height <= 0) height = 300;
	if (height > 800) height = 800;
	
	BeatPluginHTMLWindow *panel = [BeatPluginHTMLWindow.alloc initWithHTML:html width:width height:height host:self];
	//[self.delegate.documentWindow addChildWindow:panel ordered:NSWindowAbove];
	[panel makeKeyAndOrderFront:nil];
	
	if (_pluginWindows == nil) {
		_pluginWindows = [NSMutableArray array];
		[_delegate registerPlugin:self];
	}
	[_pluginWindows addObject:panel];
	panel.delegate = self;
	panel.callback = callback;
	
	return panel;
}

- (void)runCallback:(JSValue*)callback withArguments:(NSArray*)arguments {
	if (!callback || callback.isUndefined) return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		self.inCallback = YES;
		[callback callWithArguments:arguments];
		self.inCallback = NO;
		
		if (self.terminateAfterCallback) {
			NSLog(@"... terminate post callback");
			[self end];
		}
	});
}

- (void)closePluginWindow:(id)sender {
	if (_terminating) return;
	
	BeatPluginHTMLWindow *window = (BeatPluginHTMLWindow*)sender;
	window.isClosing = YES;
	
	// Store callback
	JSValue *callback = window.callback;
		
	// Run callback
	if (!callback.isUndefined && ![callback isNull]) {
		[self runCallback:callback withArguments:nil];
	}
	
	// Close window and remove its reference
	[_pluginWindows removeObject:window];
	[window closeWindow];
}

- (void)windowWillClose:(NSNotification *)notification {
	NSLog(@"HTML window will close");
	//_terminating = YES;
	
	BeatPluginHTMLWindow *window = notification.object;
	if (window == nil) return;
	
	window.isClosing = YES;
	
	// Remove webview from memory, for sure
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"sendData"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"call"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"callAndLog"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"log"];
	
	[window.webview removeFromSuperview];
	
	//[self end];
}


#pragma mark - Tagging interface

- (NSArray*)availableTags {
	return [BeatTagging tags];
}
- (NSDictionary*)tagsForScene:(OutlineScene *)scene
{
	return [self.delegate.tagging tagsForScene:scene];
}

#pragma mark - Pagination interface

- (BeatPaginator*)paginator:(NSArray*)lines {
	BeatPaginator *paginator = [[BeatPaginator alloc] initWithScript:lines printInfo:_delegate.printInfo];
	return paginator;
}

#pragma mark - Widget interface and Plugin UI API

- (BeatPluginUIView*)widget:(CGFloat)height {
	// Allow only one widget view
	if (_widgetView) return _widgetView;
	
	self.resident = YES;
	[self.delegate registerPlugin:self];
	
	BeatPluginUIView *view = [BeatPluginUIView.alloc initWithHeight:height];
	_widgetView = view;
	[_delegate addWidget:_widgetView];
	
	return view;
}

- (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame {
	return [BeatPluginUIButton buttonWithTitle:name action:action frame:frame];
}
- (BeatPluginUIDropdown*)dropdown:(nonnull NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame {
	return [BeatPluginUIDropdown withItems:items action:action frame:frame];
}
- (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame {
	return [BeatPluginUICheckbox withTitle:title action:action frame:frame];
}
- (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName {
	return [BeatPluginUILabel withText:title frame:frame color:color size:size font:fontName];
}


#pragma mark - Printing interface

- (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback {
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo.copy;
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
		self.printer = [[WebPrinter alloc] init];
		
		if (settings[@"orientation"]) {
			NSString *orientation = [(NSString*)settings[@"orientation"] lowercaseString];
			if ([orientation isEqualToString:@"landscape"]) printInfo.orientation = NSPaperOrientationLandscape;
			else printInfo.orientation = NSPaperOrientationPortrait;
		} else printInfo.orientation = NSPaperOrientationPortrait;
		
		if (settings[@"paperSize"]) {
			NSString *paperSize = [(NSString*)settings[@"paperSize"] lowercaseString];
			if ([paperSize isEqualToString:@"us letter"]) [BeatPaperSizing setPageSize:BeatUSLetter printInfo:printInfo];
			else if ([paperSize isEqualToString:@"a4"]) [BeatPaperSizing setPageSize:BeatA4 printInfo:printInfo];
		}
		
		[self.printer printHtml:html printInfo:printInfo callback:^{
			if (callback) [callback callWithArguments:nil];
		}];
	});
}

#pragma mark - Window interface

- (void)nextTab {
	[self.delegate.documentWindow selectNextTab:nil];
}
- (void)previousTab {
	[self.delegate.documentWindow selectPreviousTab:nil];
}

#pragma mark - Utilities

- (NSArray*)screen {
	NSRect screen = self.delegate.documentWindow.screen.frame;
	return @[ @(screen.origin.x), @(screen.origin.y), @(screen.size.width), @(screen.size.height) ];
}
- (NSArray*)windowFrame {
	NSRect frame = self.delegate.documentWindow.frame;
	return @[ @(frame.origin.x), @(frame.origin.y), @(frame.size.width), @(frame.size.height) ];
}

- (void)setPropertyValue:(NSString*)key value:(id)value {
	[self.delegate setPropertyValue:key value:value];
}
- (id)getPropertyValue:(NSString *)key {
	return [self.delegate getPropertyValue:key];
}

- (id)objc_call:(NSString*)methodName args:(NSArray*)arguments {
	
	Class class = self.delegate.class;
	
	SEL selector = NSSelectorFromString(methodName);
	Method method = class_getClassMethod(class, selector);
	
	char returnType[10];
	method_getReturnType(method, returnType, 10);
	
	if (![self.delegate.document respondsToSelector:selector]) {
		[self log:[NSString stringWithFormat:@"Unknown selector: %@", methodName]];
		return nil;
	}
	
	//NSMethodSignature* signature = [NSMethodSignature signatureWithObjCTypes:"v@:BqfdIi"];
	NSMethodSignature* signature = [self.delegate.document methodSignatureForSelector:selector];
	
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
	invocation.target = self.delegate.document;
	invocation.selector = selector;
	
	@try {
		// Set arguments
		for (NSInteger i=0; i < arguments.count; i++) {
			id argument = arguments[i];
			[invocation setArgument:&argument atIndex:i + 2]; // Offset by 2, because 0 = target, 1 = method
		}

		[invocation invoke];
		
		NSArray * __unsafe_unretained tempResultSet;
		[invocation getReturnValue:&tempResultSet];
		NSArray *resultSet = tempResultSet;
		return resultSet;
		
	} @catch (NSException *exception) {
		[self log:[NSString stringWithFormat:@"Objective-C call failed: %@", exception]];
	}
	
	return nil;
	

	
}

#pragma mark - Document utilities

- (NSString*)previewHTML {
	return _delegate.previewHTML;
}

#pragma mark - Parser data delegation

- (NSArray*)lines
{
	return self.delegate.parser.lines;
}
- (NSArray*)linesForScene:(id)sceneId
{
	return [self.delegate.parser linesForScene:(OutlineScene*)sceneId];
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

- (Line*)lineAtIndex:(NSInteger)index {
	return [_delegate.parser lineAtPosition:index];
}
- (OutlineScene*)sceneAtIndex:(NSInteger)index {
	return [_delegate.parser sceneAtIndex:index];
}

- (NSDictionary*)type {
	if (!_type) _type = Line.typeDictionary;
	return _type;
}

- (NSString*)scenesAsJSON {
	[self.delegate.parser createOutline];
	
	NSMutableArray *scenesToSerialize = [NSMutableArray array];
	
	for (OutlineScene* scene in self.delegate.parser.scenes) {
		[scenesToSerialize addObject:scene.forSerialization];
	}
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:scenesToSerialize options:NSJSONWritingPrettyPrinted error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	return json;
}

- (NSString*)outlineAsJSON {
	[self.delegate.parser createOutline];
	
	NSMutableArray *scenesToSerialize = [NSMutableArray array];
	
	for (OutlineScene* scene in self.delegate.parser.outline) {
		[scenesToSerialize addObject:scene.forSerialization];
	}
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:scenesToSerialize options:NSJSONWritingPrettyPrinted error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	return json;
}

- (NSString*)linesAsJSON {
	NSMutableArray *linesToSerialize = [NSMutableArray array];
	
	for (Line* line in self.delegate.parser.lines) {
		[linesToSerialize addObject:line.forSerialization];
	}
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:linesToSerialize options:NSJSONWritingPrettyPrinted error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	return json;
}

- (void)setColor:(NSString *)color forScene:(OutlineScene *)scene {
	[_delegate setColor:color forScene:scene];
}

- (OutlineScene*)getCurrentScene {
	return _delegate.currentScene;
}
- (OutlineScene*)getSceneAt:(NSInteger)position {
	return [_delegate getCurrentSceneWithPosition:position];
}

- (void)parse
{
	[self.delegate.parser createOutline];
}

- (void)newDocument:(NSString*)string
{
	if (string.length) [(BeatAppDelegate*)NSApp.delegate newDocumentWithContents:string];
	else [NSDocumentController.sharedDocumentController newDocument:nil];
}

- (Line*)currentLine {
	return _delegate.currentLine;
}

- (ContinuousFountainParser*)currentParser {
	if (!_currentParser) _currentParser = _delegate.parser; 
	return _currentParser;
}

- (ContinuousFountainParser*)parser:(NSString*)string {
	// Catch document settings
	NSRange settingsRange = [[[BeatDocumentSettings alloc] init] readSettingsAndReturnRange:string];
	if (settingsRange.length > 0) {
		string = [self removeRange:settingsRange from:string];
	}
	
	ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initWithString:string];
	return parser;
}
- (NSString*)removeRange:(NSRange)range from:(NSString*)string {
	NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:(NSRange){0, string.length}];
	[indexSet removeIndexesInRange:range];
	
	NSMutableString *result = [NSMutableString string];
	[indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[result appendString:[string substringWithRange:range]];
	}];
	
	return result;
}

#pragma mark - Document Settings

// Plugin-specific document settings (prefixed by plugin name)
- (id)getDocumentSetting:(NSString*)settingName {
	NSString *key = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	return [_delegate.documentSettings get:key];
}
- (void)setDocumentSetting:(NSString*)settingName setting:(id)value {
	NSString *key = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	[_delegate.documentSettings set:key as:value];
}

// Access to raw document settings (NOT prefixed by plugin name)
- (id)getRawDocumentSetting:(NSString*)settingName {
	return [_delegate.documentSettings get:settingName];
}

- (void)setRawDocumentSetting:(NSString*)settingName setting:(id)value {
	[_delegate.documentSettings set:settingName as:value];
}


#pragma mark - Formatting

- (void)reformat:(Line *)line {
	if (line) [_delegate formatLine:line];
}
- (void)reformatRange:(NSInteger)loc len:(NSInteger)len {
	[_delegate forceFormatChangesInRange:(NSRange){ loc, len }];
}

#pragma mark - Temporary attributes

- (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
	NSColor *color = [BeatColors color:hexColor];
	[_delegate.textView.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
}
- (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len {
	[_delegate forceFormatChangesInRange:(NSRange){ loc, len }];
}

- (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
	NSColor *color = [BeatColors color:hexColor];
	[_delegate.textView.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
}

- (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len {
	[_delegate forceFormatChangesInRange:(NSRange){ loc, len }];
}


#pragma mark - WebKit controller

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
	if ([message.name isEqualToString:@"log"]) {
		[self log:message.body];
	}
	else if ([message.name isEqualToString:@"sendData"]) {
		if (_context) [self receiveDataFromHTMLPanel:message.body];
	}
	else if ([message.name isEqualToString:@"call"]) {
		if (_context) [_context evaluateScript:message.body];
	}
	else if ([message.name isEqualToString:@"callAndLog"]) {
		if (_context) {
			[_context evaluateScript:message.body];
			[self log:[NSString stringWithFormat:@"Evaluate: %@", message.body]];
		}
	}

}

@end
/*

 No one is thinking about the flowers
 no one is thinking about the fish
 no one wants
 to believe that the garden is dying
 
 */
