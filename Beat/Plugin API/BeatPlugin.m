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
#import <BeatCore/BeatRevisions.h>
#import "BeatConsole.h"
#import "BeatPreview.h"
#import "Beat-Swift.h"
#import <objc/runtime.h>

@interface BeatPlugin ()
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) JSValue *sceneCompletionCallback;
@property (nonatomic) JSValue *characterCompletionCallback;
@property (nonatomic) JSValue *documentSavedCallback;
@property (nonatomic) WKWebView *sheetWebView;
@property (nonatomic) BeatPluginData *plugin;
@property (nonatomic) NSMutableArray *timers;
@property (nonatomic) NSMutableArray *speakSynths;
@property (nonatomic, nullable) JSValue* updateMethod;
@property (nonatomic, nullable) JSValue* updateSelectionMethod;
@property (nonatomic, nullable) JSValue* updateOutlineMethod;
@property (nonatomic, nullable) JSValue* updateSceneMethod;
@property (nonatomic, nullable) JSValue* documentDidBecomeMainMethod;
@property (nonatomic, nullable) JSValue* updatePreviewMethod;
@property (nonatomic, nullable) JSValue* escapeMethod;
@property (nonatomic) bool resident;
@property (nonatomic) bool terminating;
@property (nonatomic) bool windowClosing;
@property (nonatomic) bool inCallback;
@property (nonatomic) bool terminateAfterCallback;
@property (nonatomic) NSMutableArray *pluginWindows;
@property (nonatomic) NSDictionary *type;
@property (nonatomic) WebPrinter *printer;
@property (nonatomic) BeatPluginUIView *widgetView;
@property (nonatomic) NSMutableArray<NSMenuItem*>* menus;
@end

@implementation BeatPlugin

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
	
	// Create virtual machine and JS context
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];
	
	[self setupErrorHandler];
	[self setupRequire];
	
	[_context setObject:self forKeyedSubscript:@"Beat"];
	
	return self;
}

#pragma mark - Helpers

- (void)setupErrorHandler {
	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		if (NSThread.isMainThread) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = [BeatLocalization localizedStringForKey:@"plugins.errorRunningScript"];
			alert.informativeText = [NSString stringWithFormat:@"%@", exception];
			[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
			[alert runModal];
		} else {
			NSString *errMsg = [NSString stringWithFormat:@"Error: %@", exception];
			[BeatConsole.shared logToConsole:errMsg pluginName:@"Plugin parser"];
		}
	}];
}

/** Creates `require` function in plugin scope for importing JavaScript.
 - note: This can be used to import JavaScript either from inside the plugin container or from the app bundle. JS modules inside the app bundle should be required **without** `.js` extension.
 
 */
- (void)setupRequire {
	// Thank you, ocodo on stackoverflow.
	// Based on https://github.com/kasper/phoenix
	BeatPlugin * __weak weakSelf = self;
	
	self.context[@"require"] = ^(NSString *path) {
		NSString *modulePath = [[BeatPluginManager.sharedManager pathForPlugin:weakSelf.pluginName] stringByAppendingPathComponent:path];
		modulePath = [weakSelf resolvePath:modulePath];
		
		if(![NSFileManager.defaultManager fileExistsAtPath:modulePath]) {
			// File doesn't exist inside the plugin container. Let's see if it can be found inside the app container.
			NSURL *url = [NSBundle.mainBundle URLForResource:path.lastPathComponent withExtension:@"js"];
			if (url == nil) {
				NSString *message = [NSString stringWithFormat:@"Require: File “%@” does not exist.", path];
				weakSelf.context.exception = [JSValue valueWithNewErrorFromMessage:message inContext:weakSelf.context];
				return;
			} else {
				modulePath = url.path;
			}
		}
		
		[weakSelf importScript:modulePath];
	};
}

/// Load JavaScript into plugin scope from any path. This is called by the block defined in `setupRequire`.
- (void)importScript:(NSString *)path {
	NSError *error;
	NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	if (error) {
		NSString *errorMsg = [NSString stringWithFormat:@"Error: Could not import JavaScript module '%@'", path.lastPathComponent];
		[self log:errorMsg];
		return;
	}
	
	[self.context evaluateScript:script];
}


#pragma mark - Running Scripts

/// Load plugin data with the given data.
- (void)loadPlugin:(BeatPluginData*)plugin
{
	self.plugin = plugin;
	self.pluginName = plugin.name;
	
	[BeatPluginManager.sharedManager pathForPlugin:plugin.name];
	
	[self runScript:plugin.script];
}

/// Runs the JavaScript string
- (void)runScript:(NSString*)pluginString
{
	//pluginString = [self preprocess:pluginString];
	[self.context evaluateScript:pluginString];
	
	// Kill it if the plugin is not resident
	if (!self.sheet && !self.resident && self.pluginWindows.count < 1 && !self.widgetView) {
		[self end];
	}
}

- (NSString *)resolvePath:(NSString *)path {
	path = path.stringByResolvingSymlinksInPath;
	return path.stringByStandardizingPath;
}


/// Force-quit a resident plugin. Used mostly by Beat to kill a background plugin by unchecking it under the Tools menu.
- (void)forceEnd {
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
	[self clearMenus];
	
	[_delegate deregisterPlugin:self];
}

/// Restarts the plugin, clearing it from memory first.
- (void)restart {
	[self end];
	[_delegate runPluginWithName:self.pluginName];
}

/// Quits the current plugin. **Required** when using plugins with callbacks.
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
	
	// Clear menus
	[self clearMenus];
	
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

/// Give focus back to the editor
- (void)focusEditor {
	[_delegate focusEditor];
}

/// Opens plugin developer log
- (void)openConsole {
	[BeatConsole.shared openConsole];
}
/// Clears plugin log
- (IBAction)clearConsole:(id)sender {
	[BeatConsole.shared clearConsole];
}

/// Check compatibility with Beat version number
- (bool)compatibleWith:(NSString *)version {
	return [BeatPluginManager.sharedManager isCompatible:version];
}


#pragma mark - Resident plugin

/// Make the plugin stay running in the background.
- (void)makeResident {
	_resident = YES;
	[_delegate registerPlugin:self];
}


#pragma mark - Resident plugin listeners

/** Creates a listener for changes in editor text.
 - note:When text is changed, selection will change, too. Avoid creating infinite loops by listening to both changes.
 */
- (void)onTextChange:(JSValue*)updateMethod {
	[self setUpdate:updateMethod];
}
- (void)setUpdate:(JSValue *)updateMethod {
	// Save callback
	_updateMethod = updateMethod;
	[self makeResident];
}
- (void)update:(NSRange)range {
	if (!_updateMethod || [_updateMethod isNull]) return;
	if (!self.onTextChangeDisabled) [_updateMethod callWithArguments:@[@(range.location), @(range.length)]];
}

/// Creates a listener for changing selection in editor.
- (void)onSelectionChange:(JSValue*)updateMethod {
	[self setSelectionUpdate:updateMethod];
}
- (void)setSelectionUpdate:(JSValue *)updateMethod {
	// Save callback for selection change update
	_updateSelectionMethod = updateMethod;
	
	[self makeResident];
}
- (void)updateSelection:(NSRange)selection {
	if (!_updateSelectionMethod || [_updateSelectionMethod isNull]) return;
	if (!self.onSelectionChangeDisabled) [_updateSelectionMethod callWithArguments:@[@(selection.location), @(selection.length)]];
}

/// Creates a listener for changes in outline.
- (void)onOutlineChange:(JSValue*)updateMethod {
	[self setOutlineUpdate:updateMethod];
}
- (void)setOutlineUpdate:(JSValue *)updateMethod {
	// Save callback for selection change update
	_updateOutlineMethod = updateMethod;
	
	[self makeResident];
}
- (void)updateOutline:(NSArray*)outline {
	if (!_updateOutlineMethod || [_updateOutlineMethod isNull]) return;
	if (!self.onOutlineChangeDisabled) [_updateOutlineMethod callWithArguments:self.delegate.parser.outline];
}

/// Creates a listener for selecting a new scene.
- (void)onSceneIndexUpdate:(JSValue*)updateMethod {
	[self setSceneIndexUpdate:updateMethod];
}
- (void)setSceneIndexUpdate:(JSValue*)updateMethod {
	// Save callback for selection change update
	_updateSceneMethod = updateMethod;
	[self makeResident];
}
- (void)updateSceneIndex:(NSInteger)sceneIndex {
	if (!self.onSceneIndexUpdateDisabled) [_updateSceneMethod callWithArguments:@[@(sceneIndex)]];
}

/// Creates a listener for escape key
- (void)onEscape:(JSValue*)updateMethod {
	_escapeMethod = updateMethod;
	[self makeResident];
}
- (void)escapePressed {
	if (!_escapeMethod || [_escapeMethod isNull]) return;
	[_escapeMethod callWithArguments:nil];
}


/// Creates a listener for the window becoming main.
- (void)onDocumentBecameMain:(JSValue*)updateMethod {
	_documentDidBecomeMainMethod = updateMethod;
	[self makeResident];
}
- (void)documentDidBecomeMain {
	[_documentDidBecomeMainMethod callWithArguments:nil];
	[self refreshMenus];
}
- (void)documentDidResignMain {
	[self refreshMenus];
}

/// Creates a listener for when preview was updated.
- (void)onPreviewFinished:(JSValue*)updateMethod {
	_updatePreviewMethod = updateMethod;
	[self makeResident];
}
- (void)previewDidFinish {
	[_updatePreviewMethod callWithArguments:nil];
}

/// Creates a listener for when document was saved.
- (void)onDocumentSaved:(JSValue*)updateMethod {
	_documentSavedCallback = updateMethod;
	[self makeResident];
}
- (void)documentWasSaved {
	[_documentSavedCallback callWithArguments:nil];
}

#pragma mark - Resident plugin data providers

/// Callback for when scene headings are being autocompleted. Can be used to inject data into autocompletion.
- (void)onSceneHeadingAutocompletion:(JSValue*)callback {
	_sceneCompletionCallback = callback;
	[self makeResident];
}
/// Allows the plugin to inject data to scene heading autocompletion list. If the plugin does not have a completion callback, it's ignored.
- (NSArray*)completionsForSceneHeadings {
	if (_sceneCompletionCallback == nil) return @[];
	
	JSValue *value = [_sceneCompletionCallback callWithArguments:nil];
	if (!value.isArray) return @[];
	else return value.toArray;
}
/// Callback for when character cues are being autocompleted. Can be used to inject data into autocompletion.
- (void)onCharacterAutocompletion:(JSValue*)callback {
	_characterCompletionCallback = callback;
	[self makeResident];
}
/// Allows the plugin to inject data to character autocompletion list. If the plugin does not have a completion callback, it's ignored.
- (NSArray*)completionsForCharacters {
	if (_characterCompletionCallback == nil) return @[];
	
	JSValue *value = [_characterCompletionCallback callWithArguments:nil];
	if (!value.isArray) return @[];
	else return value.toArray;
}

#pragma mark - Import/Export callbacks

/** Creates an import handler.
 @param etensions Array of allowed file extensions
 @param callback Callback for handling the actual import. The callback block receives the file contents as string.
*/
- (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback {
	self.importedExtensions = extensions;
	self.importCallback = callback;
}
/// Creates an export handler.
- (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback {
	self.exportedExtensions = extensions;
	self.exportCallback = callback;
}


#pragma mark - Multithreading

/// Shorthand for `dispatch()`
- (void)async:(JSValue*)callback {
	[self dispatch:callback];
}
/// Shorthand for `dispatch_sync()`
- (void)sync:(JSValue*)callback {
	[self dispatch_sync:callback];
}

/// Runs the given block in a **background thread**
- (void)dispatch:(JSValue*)callback {
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		[callback callWithArguments:nil];
	});
}
/// Runs the given block in **main thread**
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

/// Creates a `BeatPluginTimer` object, which fires after the given interval (seconds)
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

/// Removes unused timers from memory.
- (void)cleanInvalidTimers {
	NSMutableArray *timers = NSMutableArray.new;
	
	for (int i=0; i < _timers.count; i++) {
		BeatPluginTimer *timer = _timers[i];
		if (timer.isValid) [timers addObject:timer];
	}
	
	_timers = timers;
}

/// Kills all background instances that might have been created by the plugin.
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

/** Presents a save dialog.
 @param format Allowed file extension
 @param callback If the user didn't click on cancel, callback receives an array of paths (containing only a single path). When clicking cancel, the return parameter is nil.
 */
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

/// Writes string content to the given path.
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

/** Presents an open dialog box.
 @param format Array of file extensions allowed to be opened
 @param callback Callback is run after the open dialog is closed. If the user selected a file, the callback receives an array of paths, though it contains only a single path.
*/
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

/** Presents an open dialog box which allows selecting multiple files.
 @param format Array of file extensions allowed to be opened
 @param callback Callback is run after the open dialog is closed. If the user selected a file, the callback receives an array of paths.
*/
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
}

/// Returns the given path as a string (from anywhere in the system)
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


/// Returns string rendition of a PDF
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

/// Returns the given file in plugin container as string
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

/// Returns the file in app bundle as a string
- (NSString*)appAssetAsString:(NSString *)filename
{
	NSString *path = [NSBundle.mainBundle pathForResource:filename.stringByDeletingPathExtension ofType:filename.pathExtension];
	
	if (path) {
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	} else {
		[self log:@"Can't find '%@' in app bundle"];
		return @"";
	}
}

/// Attempts to open  the given path in workspace (system)
- (void)openInWorkspace:(NSString*)path {
	[NSWorkspace.sharedWorkspace openFile:path];
}



#pragma mark - Scripting methods accessible via JS

/// Logs the given message to plugin developer log
- (void)log:(NSString*)string
{
	if (string == nil) return;
	
	BeatConsole *console = BeatConsole.shared;
	if (NSThread.isMainThread) [console logToConsole:string pluginName:_pluginName];
	else {
		// Allow logging in background thread
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[console logToConsole:string pluginName:self.pluginName];
		});
	}
}

/// Scroll to given location in editor window
- (void)scrollTo:(NSInteger)location
{
	[self.delegate scrollTo:location];
}

/// Scroll to the given line in editor window
- (void)scrollToLine:(Line*)line
{
	@try {
		[_delegate scrollToLine:line];
	}
	@catch (NSException *e) {
		[self reportError:@"Plugin tried to access an unknown line" withText:line.string];
	}
}

/// Scrolls to the given line index in editor window
- (void)scrollToLineIndex:(NSInteger)index
{
	[self.delegate scrollToLineIndex:index];
}

/// Scrolls to the given scene index in editor window
- (void)scrollToSceneIndex:(NSInteger)index
{
	[self.delegate scrollToSceneIndex:index];
}

/// Scrolls to the given scene in editor window
- (void)scrollToScene:(OutlineScene*)scene
{
	@try {
		[self.delegate scrollToScene:scene];
	}
	@catch (NSException *e) {
		[self reportError:@"Can't find scene" withText:@"Plugin tried to access an unknown scene"];
	}
}

/// Adds a string into the editor at given index (location)
- (void)addString:(NSString*)string toIndex:(NSUInteger)index
{
	[self.delegate addString:string atIndex:index];
}

/// Replaces the given range with a string
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

/// Returns the selected range in editor
- (NSRange)selectedRange
{
	return self.delegate.selectedRange;
}

/// Sets  the selected range in editor
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

/// Returns the plain-text string in editor
- (NSString*)getText
{
	return _delegate.text;
}

/// Report a plugin error
- (void)reportError:(NSString*)title withText:(NSString*)string {
	// In the main thread, display errors as a modal window
	if (NSThread.isMainThread) [self alert:title withText:string];
	// Inn a background thread errors are logged to console
	else [self log:[NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string]];
}

/// Presents an alert box
- (void)alert:(NSString*)title withText:(NSString*)info
{
	if ([info isEqualToString:@"undefined"]) info = @"";
	
	NSAlert *alert = [self dialog:title withInfo:info];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert runModal];
}

/// Presents a confirmation box, returning `true` if the user clicked `OK`.
- (bool)confirm:(NSString*)title withInfo:(NSString*)info
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		return YES;
	} else {
		return NO;
	}
}

/**
 Displays a more elaborate modal window. You can add multiple types of inputs, define their values and names.
 This is how you create the settings dictionary in JavaScript:
 ```
 Beat.modal({
	 title: "This is a test modal",
	 info: "You can input stuff into multiple types of fields",
	 items: [
		 {
			 type: "text",
			 name: "characterName",
			 label: "Character Name",
			 placeholder: "First Name"
		 },
		 {
			 type: "dropdown",
			 name: "characterRole",
			 label: "Role",
			 items: ["Protagonist", "Supporting Character", "Other"]
		 },
		 {
			 type: "space"
		 },
		 {
			 type: "checkbox",
			 name: "important",
			 label: "This is an important character"
		 },
		 {
			 type: "checkbox",
			 name: "recurring",
			 label: "Recurring character"
		 }
	 ]
 }, function(response) {
	 if (response) {
		 // The user clicked OK
		 Beat.log(JSON.stringify(response))
	 } else {
		 // The user clicked CANCEL
	 }
 })
 ```
 @param settings Dictionary of modal window settings. Return value dictionary contains corresponding control names.
 */
- (NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback {
	// We support both return & callback in modal windows
	
	NSString *title = (settings[@"title"] != nil) ? settings[@"title"] : @"";
	NSString *info  = (settings[@"info"] != nil) ? settings[@"info"] : @"";
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
	
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

/** Simple text input prompt.
 @param prompt Title of the dialog
 @param info Further info  displayed under the title
 @param placeholder Placeholder string for text input
 @param defaultText Default value for text input
 */
- (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText
{
	if ([placeholder isEqualToString:@"undefined"]) placeholder = @"";
	if ([defaultText isEqualToString:@"undefined"]) defaultText = @"";
	
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
	
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

/** Presents a dropdown box. Returns either the selected option or `null` when the user clicked on *Cancel*.
 @param prompt Title of the dropdown dialog
 @param withInfo Further information presented to the user below the title
 @param items Items in the dropdown box as array of strings
*/
- (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items
{
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
	
	NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0, 300, 24)];
	
	[popup addItemWithTitle:[BeatLocalization localizedStringForKey:@"plugins.input.select"]];
	
	for (id item in items) {
		// Make sure the title becomes a string
		NSString *title = [NSString stringWithFormat:@"%@", item];
		[popup addItemWithTitle:title];
	}
	[alert setAccessoryView:popup];
	NSModalResponse response = [alert runModal];
	
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		// Return an empty string if the user didn't select anything
		if ([BeatLocalization localizedStringForKey:@"plugins.input.select"]) return @"";
		else return popup.selectedItem.title;
	} else {
		return nil;
	}
}

/// Displays a simple alert box.
- (NSAlert*)dialog:(NSString*)title withInfo:(NSString*)info
{
	if ([info isEqualToString:@"undefined"]) info = @"";

	NSAlert *alert = NSAlert.new;
	alert.messageText = title;
	alert.informativeText = info;
	
	return alert;
}

#pragma mark - User settings

/// Defines user setting value for the given key.
- (void)setUserDefault:(NSString*)settingName setting:(id)value
{
	if (!_pluginName) {
		[self reportError:@"setUserDefault: No plugin name" withText:@"You need to specify plugin name before trying to save settings."];
		return;
	}
	
	NSString *keyName = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	[[NSUserDefaults standardUserDefaults] setValue:value forKey:keyName];
}
/// Gets  user setting value for the given key.
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
	okButton.title = [BeatLocalization localizedStringForKey:@"general.close"];
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

/// Makes the given window move along its parent document window. **Never use with standalone plugins.**
- (void)gangWithDocumentWindow:(NSWindow*)window
{
	[self.delegate.documentWindow addChildWindow:window ordered:NSWindowAbove];
}
/// Window no longer moves aside its document window.
- (void)detachFromDocumentWindow:(NSWindow*)window
{
	[self.delegate.documentWindow removeChildWindow:window];
}
/// Show all plugin windows.
- (void)showAllWindows
{
	if (_terminating) return;
	
	for (BeatPluginHTMLWindow *window in self.pluginWindows) {
		[window appear];
	}
}
/// All plugin windows become normal level windows, so they no longer float above the document window.
- (void)hideAllWindows
{
	if (_terminating) return;
	
	for (BeatPluginHTMLWindow *window in self.pluginWindows) {
		[window hide];
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

- (void)closePluginWindow:(id)sender
{
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

/// A plugin (HTML) window will close.
- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"HTML window will close");

	BeatPluginHTMLWindow *window = notification.object;
	if (window == nil) return;
	
	window.isClosing = YES;
	
	// Remove webview from memory
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"sendData"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"call"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"callAndLog"];
	[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"log"];
	if (@available(macOS 11.0, *)) {
		[window.webview.configuration.userContentController removeScriptMessageHandlerForName:@"callAndWait" contentWorld:WKContentWorld.pageWorld];
	}
	
	[window.webview removeFromSuperview];
}

/// When the plugin window is set as main window, the document will become active. (If applicable.)
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if (NSApp.mainWindow != self.delegate.documentWindow && self.delegate.documentWindow != nil) {
		@try {
			[self.delegate.documentWindow makeMainWindow];
		}
		@catch (NSException* e) {
			NSLog(@"Error when setting main window: %@", e);
		}
	}
}


#pragma mark - Tagging interface

- (NSArray*)availableTags
{
	return [BeatTagging tags];
}
- (NSDictionary*)tagsForScene:(OutlineScene *)scene
{
	return [self.delegate.tagging tagsForScene:scene];
}


#pragma mark - Pagination interface

- (BeatPaginator*)paginator:(NSArray*)lines
{
	BeatExportSettings* settings = self.delegate.exportSettings;
	BeatPaginator *paginator = [[BeatPaginator alloc] initWithScript:lines settings:settings];
	return paginator;
}

- (NSString*)htmlForLines:(NSArray*)lines
{
	BeatHTMLScript *html = [BeatHTMLScript.alloc initWithLines:lines];
	return html.html;
}


#pragma mark - New pagination interface

- (BeatPaginationManager*)pagination
{
	return [BeatPaginationManager.alloc initWithEditorDelegate:self.delegate.document];
}

- (BeatPaginationManager*)currentPagination
{
	return self.delegate.previewController.pagination;
}


#pragma mark - Widget interface and Plugin UI API

- (BeatPluginUIView*)widget:(CGFloat)height
{
	// Allow only one widget view
	if (_widgetView) return _widgetView;
	
	self.resident = YES;
	[self.delegate registerPlugin:self];
	
	BeatPluginUIView *view = [BeatPluginUIView.alloc initWithHeight:height];
	_widgetView = view;
	[_delegate addWidget:_widgetView];
	
	return view;
}

- (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUIButton buttonWithTitle:name action:action frame:frame];
}
- (BeatPluginUIDropdown*)dropdown:(nonnull NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUIDropdown withItems:items action:action frame:frame];
}
- (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame
{
	return [BeatPluginUICheckbox withTitle:title action:action frame:frame];
}
- (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName
{
	return [BeatPluginUILabel withText:title frame:frame color:color size:size font:fontName];
}


#pragma mark - Printing interface

- (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback
{
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

- (void)nextTab
{
	for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
	[self.delegate.documentWindow selectNextTab:nil];
}
- (void)previousTab
{
	for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
	[self.delegate.documentWindow selectPreviousTab:nil];
}

#pragma mark - Utilities

/// Returns screen frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)screen
{
	NSRect screen = self.delegate.documentWindow.screen.frame;
	return @[ @(screen.origin.x), @(screen.origin.y), @(screen.size.width), @(screen.size.height) ];
}
/// Returns window frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)getWindowFrame {
	return [self windowFrame];
}
- (NSArray*)windowFrame
{
	NSRect frame = self.delegate.documentWindow.frame;
	return @[ @(frame.origin.x), @(frame.origin.y), @(frame.size.width), @(frame.size.height) ];
}
/// Sets host document window frame
- (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height
{
	NSRect frame = NSMakeRect(x, y, width, height);
	[self.delegate.documentWindow setFrame:frame display:true];
}


#pragma mark - Objective C interface

/// Set any value in `Document` class
- (void)setPropertyValue:(NSString*)key value:(id)value
{
	[self.delegate setPropertyValue:key value:value];
}

/// Get any value in `Document` class
- (id)getPropertyValue:(NSString *)key
{
	return [self.delegate getPropertyValue:key];
}

/// Calls Objective C methods.
/// @note Do **NOT** use this if you don't know what you are doing.
- (id)objc_call:(NSString*)methodName args:(NSArray*)arguments {
	Class class = [self.delegate.document class];
	
	SEL selector = NSSelectorFromString(methodName);
	Method method = class_getClassMethod(class, selector);
	
	char returnType[10];
	method_getReturnType(method, returnType, 10);
	
	if (![self.delegate.document respondsToSelector:selector]) {
		[self log:[NSString stringWithFormat:@"Unknown selector: %@", methodName]];
		return nil;
	}
	
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

/// This crashes the whole app when needed. Can lead to data loss, so use with extreme care.
- (void)crash {
	@throw([NSException exceptionWithName:NSInternalInconsistencyException reason:@"Crash thrown by plugin" userInfo:nil]);
}

#pragma mark - Document utilities

/// Returns the plain-text file content used to save current screenplay (including settings block etc.)
- (NSString*)createDocumentFile
{
	return _delegate.createDocumentFile;
}
/// Returns the plain-text file content used to save current screenplay (including settings block etc.) with additional `BeatDocumentSettings` block
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings
{
	return [_delegate createDocumentFileWithAdditionalSettings:additionalSettings];
}
/// Returns the old HTML preview controller
- (BeatPreview*)preview
{
	return _delegate.preview;
}
/// Returns the old HTML preview content
- (NSString*)previewHTML
{
	return _delegate.preview.htmlString;
}
/// Creates a HTML render for current document, with given export settings.
- (NSString*)screenplayHTML:(NSDictionary*)exportSettings
{
	
	BeatExportSettings *settings = [BeatExportSettings
									operation:ForPrint
									document:self.delegate.document
									header:(exportSettings[@"header"]) ? exportSettings[@"header"] : @""
									printSceneNumbers:(exportSettings[@"printSceneNumbers"]) ? ((NSNumber*)exportSettings[@"printSceneNumbers"]).boolValue : true
									printNotes:(exportSettings[@"printNotes"]) ? ((NSNumber*)(exportSettings[@"printNotes"])).boolValue : false
									revisions:(exportSettings[@"revisions"]) ? (NSArray*)exportSettings[@"revisions"] : BeatRevisions.revisionColors
									scene:nil
									coloredPages:(exportSettings[@"coloredPages"]) ? ((NSNumber*)(exportSettings[@"coloredPages"])).boolValue : false
									revisedPageColor:(exportSettings[@"revisedPageColor"]) ? (exportSettings[@"revisedPageColor"]) : @""];
	
	BeatScreenplay *screenplay = [BeatScreenplay from:self.delegate.parser settings:settings];
	NSString * html = [BeatHTMLScript.alloc initWithScript:screenplay settings:settings].html;
	
	if (html) return html;
	return @"";
}

#pragma mark - Parser data delegation

/// Creates a new `Line` object with given string and type.
- (Line*)lineWithString:(NSString*)string type:(LineType)type
{
	return [Line withString:string type:type];
}
/// Returns parsed `Line` objects for current document.
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

- (Line*)lineAtPosition:(NSInteger)index
{
	return [_delegate.parser lineAtPosition:index];
}
- (OutlineScene*)sceneAtIndex:(NSInteger)index
{
	return [_delegate.parser sceneAtIndex:index];
}

- (NSDictionary*)type
{
	if (!_type) _type = Line.typeDictionary;
	return _type;
}

- (NSString*)scenesAsJSON
{
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

- (NSString*)outlineAsJSON
{
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

- (void)setColor:(NSString *)color forScene:(id)scene {
	if ([scene isKindOfClass:OutlineScene.class]) {
		[_delegate setColor:color forScene:scene];
	} else if ([scene isKindOfClass:Line.class]) {
		[_delegate setColor:color forLine:scene];
	}
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
- (id)newDocumentObject:(NSString*)string
{
	if (string.length) return [(BeatAppDelegate*)NSApp.delegate newDocumentWithContents:string];
	else return [NSDocumentController.sharedDocumentController openUntitledDocumentAndDisplay:YES error:nil];
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

- (NSDictionary*)printInfo {
	return @{
		@"paperSize": @[@(_delegate.printInfo.paperSize.width), @(_delegate.printInfo.paperSize.height)],
		@"imageableSize": @[@(_delegate.printInfo.imageablePageBounds.origin.x),
							@(_delegate.printInfo.imageablePageBounds.origin.y),
							@(_delegate.printInfo.imageablePageBounds.size.width),
							@(_delegate.printInfo.imageablePageBounds.size.height)]
	};
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
	[_delegate.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
}
- (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len {
	[_delegate forceFormatChangesInRange:(NSRange){ loc, len }];
}

- (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
	NSColor *color = [BeatColors color:hexColor];
	[_delegate.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
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

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message replyHandler:(void (^)(id _Nullable, NSString * _Nullable))replyHandler {
	if ([message.name isEqualToString:@"callAndWait"]) {
		JSValue* value = [_context evaluateScript:message.body];
		
		id returnValue;
		if (value.isArray) returnValue = value.toArray;
		else if (value.isNumber) returnValue = value.toNumber;
		else if (value.isObject) returnValue = value.toDictionary;
		else if (value.isString) returnValue = value.toString;
		else if (value.isDate) returnValue = value.toDate;
		else returnValue = nil;

		if (returnValue) replyHandler(returnValue, nil);
		else replyHandler(nil, @"Could not convert return value to JSON.");
	}
}

#pragma mark - Return revised ranges

- (void)bakeRevisions {
	[self.delegate bakeRevisions];
}
- (void)bakeRevisionsInRange:(NSInteger)loc len:(NSInteger)len {
	NSRange range = NSMakeRange(loc, len);
	NSArray *lines = [self.delegate.parser linesInRange:range];
	[BeatRevisions bakeRevisionsIntoLines:lines text:self.delegate.getAttributedText];
}
- (NSDictionary*)revisedRanges {
	return self.delegate.revisedRanges;
}


#pragma mark - Menu items

- (void)clearMenus {
	for (NSMenuItem* topMenuItem in self.menus) {
		[topMenuItem.submenu removeAllItems];
		
		// Remove menus when needed
		if ([NSApp.mainMenu.itemArray containsObject:topMenuItem]) {
			[NSApp.mainMenu removeItem:topMenuItem];
		}
	}
}

/// Adds / removes menu items based on the yurrently active document
- (void)refreshMenus {
	for (NSMenuItem* item in self.menus) {
		if (_delegate.documentWindow.mainWindow && ![NSApp.mainMenu.itemArray containsObject:item]) [NSApp.mainMenu addItem:item];
		else if (!_delegate.documentWindow.mainWindow && [NSApp.mainMenu.itemArray containsObject:item]) [NSApp.mainMenu removeItem:item];
	}
}

- (BeatPluginControlMenu*)menu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>* _Nullable)items {
	BeatPluginControlMenu* menu = [BeatPluginControlMenu.alloc initWithTitle:name];
	
	for (BeatPluginControlMenuItem* item in items) {
		[menu addItem:item];
	}
	
	NSMenuItem* topMenuItem = [NSMenuItem.alloc initWithTitle:name action:nil keyEquivalent:@""];
	
	NSMenu* mainMenu = NSApp.mainMenu;
	[mainMenu insertItem:topMenuItem atIndex:mainMenu.numberOfItems];
	[mainMenu setSubmenu:menu forItem:topMenuItem];
	
	if (self.menus == nil) self.menus = NSMutableArray.new;
	[self.menus addObject:topMenuItem];
	
	return menu;
}

- (NSMenuItem*)submenu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items {
	NSMenuItem* topItem = [NSMenuItem.alloc initWithTitle:name action:nil keyEquivalent:@""];
	
	BeatPluginControlMenu* menu = [BeatPluginControlMenu.alloc initWithTitle:name];
	for (BeatPluginControlMenuItem* item in items) [menu addItem:item];
	topItem.submenu = menu;
	
	return topItem;
}

- (NSMenuItem*)separatorMenuItem {
	return [NSMenuItem separatorItem];
}

- (BeatPluginControlMenuItem*)menuItem:(NSString*)title shortcut:(NSArray<NSString*>*)shortcut action:(JSValue*)method {
	return [BeatPluginControlMenuItem.alloc initWithTitle:title shortcut:shortcut method:method];
}

@end
/*

 No one is thinking about the flowers
 no one is thinking about the fish
 no one wants
 to believe that the garden is dying
 
 */
