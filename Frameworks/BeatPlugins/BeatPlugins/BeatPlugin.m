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
#import <BeatPagination2/BeatPagination2.h>
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatPlugins/BeatPluginAgent.h>
#import <PDFKit/PDFKit.h>

#import "BeatConsole.h"

#if TARGET_OS_OSX
#import "BeatPluginUIView.h"
#import "BeatPluginUIButton.h"
#import "BeatPluginUIDropdown.h"
#import "BeatPluginUIView.h"
#import "BeatPluginUICheckbox.h"
#import "BeatPluginUILabel.h"
#import "BeatSpeak.h"
#import "BeatHTMLPrinter.h"

#import "BeatModalAccessoryView.h"

#endif


#import <objc/runtime.h>

#if TARGET_OS_IOS
@interface BeatPlugin ()
#else
@interface BeatPlugin () <NSWindowDelegate, PluginWindowHost>
#endif

@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;

@property (nonatomic) BeatPluginData* pluginData;

@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) JSValue *sceneCompletionCallback;
@property (nonatomic) JSValue *characterCompletionCallback;
@property (nonatomic) JSValue *documentSavedCallback;
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

@property (nonatomic) NSURL* pluginURL; // URL for a container

#if !TARGET_OS_IOS
@property (nonatomic) NSMutableArray<NSMenuItem*>* menus;
@property (nonatomic) BeatPluginUIView *widgetView;
@property (nonatomic) BeatHTMLPrinter *printer;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) BeatPluginHTMLPanel* htmlPanel;
#else
@property (nonatomic) UIWindow *sheet;
@property (nonatomic) id widgetView;
#endif

@end

@implementation BeatPlugin

+ (BeatPlugin*)withName:(NSString*)name delegate:(id<BeatPluginDelegate>)delegate
{
    BeatPlugin* plugin = BeatPlugin.new;
    plugin.delegate = delegate;
    
    BeatPluginData *pluginData = [BeatPluginManager.sharedManager pluginWithName:name];
    [plugin loadPlugin:pluginData];
    
    return plugin;
}

/// For plugin containers, we'll first need to set the container, and only load the plugin afterwards
+ (BeatPlugin*)withContainer:(id<BeatPluginContainer>)container delegate:(id<BeatPluginDelegate>)delegate
{
    BeatPlugin* plugin = BeatPlugin.new;
    plugin.delegate = delegate;
    plugin.container = container;
    plugin.restorable = false;
    
    return plugin;
}

+ (BeatPlugin*)withName:(NSString*)name script:(NSString*)script delegate:(id<BeatPluginDelegate>)delegate
{
    BeatPlugin* plugin = BeatPlugin.new;
    plugin.delegate = delegate;
    
    BeatPluginData *pluginData = BeatPluginData.new;
    pluginData.name = name;
    pluginData.script = script;
    [plugin loadPlugin:pluginData];
    
    return plugin;
}

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
    
    [self setupVM];
    self.restorable = true;
	
	return self;
}

- (void)setupVM
{
    // Create virtual machine and JS context
    _vm = [[JSVirtualMachine alloc] init];
    _context = [[JSContext alloc] initWithVirtualMachine:_vm];
    
    [self setupErrorHandler];
    [self setupRequire];
        
    [_context setObject:self forKeyedSubscript:@"Beat"];
}

#pragma mark - Helpers

- (void)setupErrorHandler {
	__weak typeof(id<BeatEditorDelegate>) weakDoc = self.delegate.document;
	__weak typeof(self) weakSelf = self;
	
	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		[BeatConsole.shared openConsole];
		[BeatConsole.shared logError:exception context:weakDoc pluginName:weakSelf.pluginName];
	}];
}

/// Error handler can be replaced for special use cases
-(void)replaceErrorHandler:(void (^)(JSValue* exception))block {
	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		block(exception);
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
            NSBundle* bundle = [NSBundle bundleForClass:weakSelf.class];
			NSURL *url = [bundle URLForResource:path.lastPathComponent withExtension:@"js"];
            
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

/// Load plugin with given name
- (void)loadPluginWithName:(NSString*)name
{
    BeatPluginData *pluginData = [BeatPluginManager.sharedManager pluginWithName:name];
    if (pluginData == nil) NSLog(@"No plugin found with name: %@", pluginData);
    
    [self loadPlugin:pluginData];
}

/// Load plugin data with the given data.
- (void)loadPlugin:(BeatPluginData*)plugin
{
	self.plugin = plugin;
	self.pluginName = plugin.name;
    self.pluginData = plugin;
    self.pluginURL = plugin.url;
        
    // For contained plugins we won't use the actual name to avoid conflicts. Also inform the container of this change.
    if (self.container != nil) {
        self.pluginName = [NSString stringWithFormat:@"%@ (in container)", self.pluginName];
        self.container.pluginName = self.pluginName;
    }
    
	[self runScript:plugin.script];
}

/// Runs the JavaScript string
- (void)runScript:(NSString*)pluginString
{
	//pluginString = [self preprocess:pluginString];
	[self.context evaluateScript:pluginString];
	
	// Kill it if the plugin is not resident
	if (!self.sheet && !self.resident && self.pluginWindows.count < 1 && !self.widgetView && !self.container) {
		[self end];
	}
}
/// Runs a JavaScript string in this context
- (JSValue*)call:(NSString*)script
{
	return [self.context evaluateScript:script];
}

- (NSString *)resolvePath:(NSString *)path {
	path = path.stringByResolvingSymlinksInPath;
	return path.stringByStandardizingPath;
}


/// Force-quit a resident plugin. Used mostly by Beat to kill a background plugin by unchecking it under the Tools menu.
- (void)forceEnd {
	_terminating = YES;
    
    [self closeWindows];
	[self stopBackgroundInstances];
	
	// macOS specific nulls
#if !TARGET_OS_IOS
	// Remove widget
	if (self.widgetView != nil) [self.widgetView remove];
    
	[self clearMenus];
#endif
	
	self.plugin = nil;
		
	[_delegate.pluginAgent deregisterPlugin:self];
}

/// Closes all windows (on macOS)
- (void)closeWindows
{
#if !TARGET_OS_IOS
    if (self.htmlPanel) {
        [self.htmlPanel closePanel:nil];
        self.htmlPanel = nil;
    }
    
    if (_pluginWindows.count) {
        for (BeatPluginHTMLWindow *window in _pluginWindows) {
            [window closeWindow];
        }
    }
#endif
}

/// Restarts the plugin, clearing it from memory first.
- (void)restart {
    [self end];
    
    if (!self.container) {
        [_delegate.pluginAgent runPluginWithName:self.pluginName];
    } else {
        // If we're running the plugin a container, we won't deallocate the whole plugin.
        // Instead, we're nulling the VM and just reloading the data here.
        [self setupVM];
        [self loadPlugin:self.pluginData];
    }
}

/// Quits the current plugin. **Required** when using plugins with callbacks.
- (void)end {
	// If end was called in callback, we'll wait until it's done before killing the plugin altogether
	if (_inCallback) {
		_terminateAfterCallback = YES;
		return;
	}
	
	_terminating = YES;
	
    [self closeWindows];
	
	// Stop any timers left
	[self stopBackgroundInstances];
	
	// macOS specific nulls
#if !TARGET_OS_IOS
	// Clear menus
	[self clearMenus];

	// Remove widget
	if (self.widgetView != nil) [self.widgetView remove];
#endif
	
	self.plugin = nil;
    self.pluginData = nil;
    self.vm = nil;
    self.context = nil;
    
    // Clear all listeners
    self.updateMethod = nil;
    self.updateSceneMethod = nil;
    self.updateOutlineMethod = nil;
    self.updatePreviewMethod = nil;
    self.updateSelectionMethod = nil;
	
    // Remove from the list of running plugins
	if (_resident) [_delegate.pluginAgent deregisterPlugin:self];
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
	[_delegate.pluginAgent registerPlugin:self];
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
- (void)updateOutline:(OutlineChanges*)changes
{
	if (!_updateOutlineMethod || [_updateOutlineMethod isNull]) return;
	if (!self.onOutlineChangeDisabled) [_updateOutlineMethod callWithArguments:@[changes]];
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
    #if !TARGET_OS_IOS
	[self refreshMenus];
    #endif
}
- (void)documentDidResignMain {
    #if !TARGET_OS_IOS
	[self refreshMenus];
    #endif
}

/// Creates a listener for when preview was updated.
- (void)onPreviewFinished:(JSValue*)updateMethod {
	_updatePreviewMethod = updateMethod;
	[self makeResident];
}
/// This is an alias for onPreviewFinished
- (void)onPaginationFinished:(JSValue*)updateMethod {
	[self onPreviewFinished:updateMethod];
}
- (void)previewDidFinish:(BeatPagination*)pagination indices:(NSIndexSet*)changedIndices {
	if (self.onPreviewFinishedDisabled) return;
	
	NSMutableArray<NSNumber*>* indices = NSMutableArray.new;
	[changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		[indices addObject:@(idx)];
	}];
	
	[_updatePreviewMethod callWithArguments:@[indices, pagination]];
}

/// Creates a listener for when document was saved.
- (void)onDocumentSaved:(JSValue*)updateMethod
{
	_documentSavedCallback = updateMethod;
	[self makeResident];
}
- (void)documentWasSaved {
	[_documentSavedCallback callWithArguments:nil];
}


#pragma mark - Access other documents

#if !TARGET_OS_IOS
/// Returns all document instances
- (NSArray<id<BeatPluginDelegate>>*)documents
{
    return (NSArray<id<BeatPluginDelegate>>*)NSDocumentController.sharedDocumentController.documents;
}
- (BeatPlugin*)interface:(id<BeatPluginDelegate>)document
{
    BeatPlugin* interface = BeatPlugin.new;
    interface.delegate = document;
    return interface;
}
- (id)document
{
    return self.delegate.document;
}
#endif

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
 @param extensions Array of allowed file extensions
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
	[self dispatch:callback priority:0];
}
/// Runs the given block in a background thread
- (void)dispatch:(JSValue*)callback priority:(NSInteger)priority {
	intptr_t p;
	
	switch (priority) {
		case 1:
			p = DISPATCH_QUEUE_PRIORITY_BACKGROUND; break;
		case 2:
			p = DISPATCH_QUEUE_PRIORITY_LOW; break;
		case 3:
			p = DISPATCH_QUEUE_PRIORITY_DEFAULT; break;
		case 4:
			p = DISPATCH_QUEUE_PRIORITY_HIGH; break;
		default:
			p = DISPATCH_QUEUE_PRIORITY_DEFAULT;
			break;
	}
	
	dispatch_async(dispatch_get_global_queue(p, 0), ^(void){
		[callback callWithArguments:nil];
	});
}
/// Runs the given block in **main thread**
- (void)dispatch_sync:(JSValue*)callback {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[callback callWithArguments:nil];
	});
}

- (bool)isMainThread {
	return NSThread.isMainThread;
}

- (JSValue*)fetch:(JSValue*)callback {
	return nil;
}

#pragma mark - Speak

#if !TARGET_OS_IOS
- (BeatSpeak*)speakSynth {
	if (!_speakSynths) _speakSynths = NSMutableArray.new;	
	
	BeatSpeak *synth = BeatSpeak.new;
	[_speakSynths addObject:synth];
	
	return synth;
}
#endif

- (void)killSynths {
    #if !TARGET_OS_IOS
    for (BeatSpeak *synth in _speakSynths) {
        [synth stopSpeaking];
    }
    [_speakSynths removeAllObjects];
    _speakSynths = nil;
    #endif
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
	
    [self killSynths];
}


#pragma mark - File i/o

#pragma mark macOS only
#if !TARGET_OS_IOS
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

	/** Presents an open dialog box.
	 @param formats Array of file extensions allowed to be opened
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
	}

	/** Presents an open dialog box which allows selecting multiple files.
	 @param formats Array of file extensions allowed to be opened
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
#endif

#pragma mark Generic writing and reading methods

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

/// Attempts to open  the given path in workspace (system)
- (void)openInWorkspace:(NSString*)path {
#if !TARGET_OS_IOS
	[NSWorkspace.sharedWorkspace openFile:path];
#else
    NSURL *fileURL = [NSURL fileURLWithPath:path];

    UIDocumentInteractionController *documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    [documentInteractionController presentOptionsMenuFromRect:CGRectZero inView:self.delegate.textView animated:YES];
#endif
}


#pragma mark - Access plugin assets

/// Returns the given file in plugin container as string
- (NSString*)assetAsString:(NSString *)filename
{
	if ([_plugin.files containsObject:filename]) {
		NSString *path = [[BeatPluginManager.sharedManager pathForPlugin:_plugin.name] stringByAppendingPathComponent:filename];
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	} else {
        NSString* msg = [NSString stringWithFormat:@"Can't find bundled file '%@' – Are you sure the plugin is contained in a self-titled folder? For example: Plugin.beatPlugin/Plugin.beatPlugin", filename];
		[self log:msg];
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
        NSString* msg = [NSString stringWithFormat:@"Can't find '%@' in app bundle", filename];
		[self log:msg];
		return @"";
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


#pragma mark - Logging

/// Logs the given message to plugin developer log
- (void)log:(NSString*)string
{
    if (string == nil) string = @"";
	
	#if !TARGET_OS_IOS
		BeatConsole *console = BeatConsole.shared;
		if (NSThread.isMainThread) [console logToConsole:string pluginName:(_pluginName != nil) ? _pluginName : @"General" context:self.delegate.document];
		else {
			// Allow logging in background thread
			dispatch_async(dispatch_get_main_queue(), ^(void){
				[console logToConsole:string pluginName:self.pluginName context:self.delegate.document];
			});
		}
	#else
		NSLog(@"%@: %@", self.pluginName, string);
	#endif
}


#pragma mark - Scrolling

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


#pragma mark - Text I/O

/// Adds a string into the editor at given index (location)
- (void)addString:(NSString*)string toIndex:(NSUInteger)index
{
	[self.delegate.textActions addString:string atIndex:index];
}

/// Replaces the given range with a string
- (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string
{
	NSRange range = NSMakeRange(from, length);
	@try {
		[self.delegate.textActions replaceRange:range withString:string];
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
	//[self log:[NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string]];
    NSString* msg = [NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string];
    [BeatConsole.shared logError:msg context:self pluginName:self.pluginName];
}


#pragma mark - Localization

// Localizes the given string
- (NSString*)localize:(NSString*)string
{
    return [BeatLocalization localizeString:string];
}


#pragma mark - Modals

/// Presents an alert box
- (void)alert:(NSString*)title withText:(NSString*)info
{
#if TARGET_OS_IOS
	// Do something on iOS
	NSLog(@"WARNING: Beat.alert missing on iOS");
#else
	// Send back to main thread
	if (!NSThread.isMainThread) {
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[self alert:title withText:info];
		});
		return;
	}
	if ([info isEqualToString:@"undefined"]) info = @"";
	
	NSAlert *alert = [self dialog:title withInfo:info];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert runModal];
#endif
}

/// Presents a confirmation box, returning `true` if the user clicked `OK`.
- (bool)confirm:(NSString*)title withInfo:(NSString*)info
{
#if TARGET_OS_IOS
	// Do something on iOS
	NSLog(@"WARNING: Beat.confirm missing on iOS");
	return false;
#else
	NSAlert *alert = NSAlert.new;
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
	[alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
	
	NSModalResponse response = [alert runModal];
	
	return (response == NSModalResponseOK || response == NSAlertFirstButtonReturn);
#endif
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
#if !TARGET_OS_IOS
	if (!NSThread.isMainThread) {
		[self log:@"ERROR: Trying to create a modal from background thread"];
		return nil;
	}
	
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
#else
	// Do something on iOS
	NSLog(@"WARNING: Beat.modal missing on iOS");
	return @{};
#endif
}

/** Simple text input prompt.
 @param prompt Title of the dialog
 @param info Further info  displayed under the title
 @param placeholder Placeholder string for text input
 @param defaultText Default value for text input
 */
- (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText
{
#if !TARGET_OS_IOS
	if (!NSThread.isMainThread) {
		[self log:@"ERROR: Trying to create a prompt from background thread"];
		return nil;
	}
	
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
#else
	NSLog(@"WARNING: Beat.prompt missing on iOS");
	return @"";
#endif
}

/** Presents a dropdown box. Returns either the selected option or `null` when the user clicked on *Cancel*.
 @param prompt Title of the dropdown dialog
 @param info Further information presented to the user below the title
 @param items Items in the dropdown box as array of strings
*/
- (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items
{
#if !TARGET_OS_IOS
	if (!NSThread.isMainThread) {
		[self log:@"ERROR: Trying to create a dropdown prompt from background thread"];
		return nil;
	}
	
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
		if ([popup.selectedItem.title isEqualToString: [BeatLocalization localizedStringForKey:@"plugins.input.select"]]) return @"";
		else return popup.selectedItem.title;
	} else {
		return nil;
	}
#else
	NSLog(@"WARNING: Beat.dropdownPrompt missing on iOS");
	return @"";
#endif
}

#if !TARGET_OS_IOS
/// Displays a simple alert box.
- (NSAlert*)dialog:(NSString*)title withInfo:(NSString*)info
{
	if (!NSThread.isMainThread) {
		[self log:@"ERROR: Trying to create a dialog from background thread"];
		return nil;
	}
	
	if ([info isEqualToString:@"undefined"]) info = @"";

	NSAlert *alert = NSAlert.new;
	alert.messageText = title;
	alert.informativeText = info;
	
	return alert;
}
#endif

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

/** Returns a timer object, and immediately fires it.
 @param seconds Delay in seconds
 @param callback Closure which is run after the delay
 */
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
#if !TARGET_OS_IOS
	if (_delegate.documentWindow.attachedSheet) return;

    BeatPluginHTMLPanel* panel = [BeatPluginHTMLPanel.alloc initWithHtml:html width:width height:height + 35.0 host:self cancelButton:cancelButton callback:callback];
    self.htmlPanel = panel;
    
    [self makeResident];
    
    [self.delegate.documentWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
        self.htmlPanel = nil;
	}];
#endif
}

- (void)receiveDataFromHTMLPanel:(NSString*)json
{
	// This method actually closes the HTML panel.
	// It is called by sending a message to the script parser via webkit message handler,
	// so this works asynchronously. Keep in mind.
#if !TARGET_OS_IOS
	if ([json isEqualToString:@"(null)"]) json = @"";
	
	if (self.htmlPanel.callback != nil) {
		NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
		NSError *error;
		NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
		
        JSValue* callback = self.htmlPanel.callback;
        
        if (!error) {
            [self.htmlPanel closePanel:nil];
			[self runCallback:callback withArguments:@[jsonData]];
		} else {
            [self.htmlPanel closePanel:nil];
			[self reportError:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
		}
		
        self.htmlPanel.callback = nil;
	} else {
		// If there was no callback, it marks the end of the script
        [self.htmlPanel closePanel:nil];
		_context = nil;
	}
#endif
}

#pragma mark - Window management

#if !TARGET_OS_IOS
	/// Makes the given window move along its parent document window. **Never use with standalone plugins.**
	- (void)gangWithDocumentWindow:(NSWindow*)window
	{
		if (self.delegate.documentWindow != nil) [self.delegate.documentWindow addChildWindow:window ordered:NSWindowAbove];
	}
	/// Window no longer moves aside its document window.
	- (void)detachFromDocumentWindow:(NSWindow*)window
	{
		if (self.delegate.documentWindow != nil) [self.delegate.documentWindow removeChildWindow:window];
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
#endif


#pragma mark - HTML Window

- (void)runCallback:(JSValue*)callback withArguments:(NSArray*)arguments {
    if (!callback || callback.isUndefined) return;
        
    dispatch_async(dispatch_get_main_queue(), ^{
        self.inCallback = YES;
        [callback callWithArguments:arguments];
        self.inCallback = NO;
        
        if (self.terminateAfterCallback) {
            [self end];
        }
    });
}

#if !TARGET_OS_IOS

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
		[_delegate.pluginAgent registerPlugin:self];
	}
	[_pluginWindows addObject:panel];
	panel.delegate = self;
	panel.callback = callback;
	
	return panel;
}

/// A plugin (HTML) window will close.
- (void)windowWillClose:(NSNotification *)notification
{
	BeatPluginHTMLWindow *window = notification.object;
	if (window == nil) return;
    
	[window.webView remove];
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

#endif

/// Reliably closes a plugin window
- (void)closePluginWindow:(id)sender
{
    if (_terminating) return;

#if !TARGET_OS_IOS
    // macOS
    BeatPluginHTMLWindow *window = (BeatPluginHTMLWindow*)sender;
    
    // Store callback
    JSValue *callback = window.callback;
        
    // Run callback
    if (!callback.isUndefined && ![callback isNull]) {
        [self runCallback:callback withArguments:nil];
    }
    
    // Close window and remove its reference
    [_pluginWindows removeObject:window];
    [window closeWindow];
#else
    // iOS
    BeatPluginHTMLViewController* vc = (BeatPluginHTMLViewController*)sender;
    JSValue* callback = vc.callback;
    
    // Run callback
    if (!callback.isUndefined && !callback.isNull) {
        [self runCallback:callback withArguments:nil];
    }
    
    [vc closePanel:nil];
#endif

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

- (id)paginator:(NSArray*)lines
{
	return [BeatPaginationManager.alloc initWithEditorDelegate:self.delegate.document];
}


#pragma mark - New pagination interface

- (BeatPaginationManager*)pagination
{
	return [BeatPaginationManager.alloc initWithEditorDelegate:self.delegate.document];
}

- (BeatPaginationManager*)currentPagination
{
	return self.delegate.pagination;
}

- (void)createPreviewAt:(NSInteger)location {
	[self.delegate createPreviewAt:NSMakeRange(location, 0) sync:true];
}

- (void)resetPreview
{
	[self.delegate resetPreview];
}



#pragma mark - Widget interface and Plugin UI API

#if !TARGET_OS_IOS
- (BeatPluginUIView *)widgetView {
	return _widgetView;
}

- (BeatPluginUIView*)widget:(CGFloat)height
{
	// Allow only one widget view
	if (_widgetView) return _widgetView;
	
	self.resident = YES;
	[self.delegate.pluginAgent registerPlugin:self];
	
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
#endif


#pragma mark - Printing interface

#if !TARGET_OS_IOS
- (NSDictionary*)printInfo
{
    NSPrintInfo* printInfo = NSPrintInfo.sharedPrintInfo;
    return @{
        @"paperSize": @(printInfo.paperSize),
        @"imageableSize": @{
            @"width": @(printInfo.imageablePageBounds.size.width),
            @"height": @(printInfo.imageablePageBounds.size.height)
        }
    };
}
- (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback
{
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo.copy;
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
        self.printer = BeatHTMLPrinter.new;
		
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
        
        if (settings[@"margins"]) {
            NSArray* margins = settings[@"margins"];
            
            for (NSInteger i=0; i<margins.count; i++) {
                NSNumber* n = margins[i];
                if (i == 0) printInfo.topMargin = n.floatValue;
                else if (i == 1) printInfo.rightMargin = n.floatValue;
                else if (i == 2) printInfo.bottomMargin = n.floatValue;
                else if (i == 3) printInfo.leftMargin = n.floatValue;
            }
        }
		
		[self.printer printHtml:html printInfo:printInfo callback:^{
			if (callback) [callback callWithArguments:nil];
		}];
	});
}
#endif


#pragma mark - Window interface

- (void)nextTab
{
#if !TARGET_OS_IOS
	for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
	[self.delegate.documentWindow selectNextTab:nil];
#endif
}
- (void)previousTab
{
#if !TARGET_OS_IOS
	for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
	[self.delegate.documentWindow selectPreviousTab:nil];
#endif
}


#pragma mark - Utilities

/// Returns screen frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)screen
{
#if TARGET_OS_IOS
    CGRect screen = self.delegate.documentWindow.screen.bounds;
#else
    CGRect screen = self.delegate.documentWindow.screen.frame;
#endif
	return @[ @(screen.origin.x), @(screen.origin.y), @(screen.size.width), @(screen.size.height) ];
}
/// Returns window frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)getWindowFrame {
	return [self windowFrame];
}
- (NSArray*)windowFrame
{
	CGRect frame = self.delegate.documentWindow.frame;
	return @[ @(frame.origin.x), @(frame.origin.y), @(frame.size.width), @(frame.size.height) ];
}
/// Sets host document window frame
- (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height
{
#if !TARGET_OS_IOS
	NSRect frame = NSMakeRect(x, y, width, height);
	[self.delegate.documentWindow setFrame:frame display:true];
#endif
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
			[invocation setArgument:&arguments atIndex:i+2]; // Offset by 2, because 0 = target, 1 = method
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
	return self.delegate.parser.scenes;
}

- (NSArray*)outline
{
    return (self.delegate.parser.outline) ? self.delegate.parser.outline : @[];
}

- (Line*)lineAtPosition:(NSInteger)index
{
	return [_delegate.parser lineAtPosition:index];
}

- (OutlineScene*)sceneAtPosition:(NSInteger)index
{
    return [_delegate.parser sceneAtPosition:index];
}

- (NSDictionary*)type
{
	if (!_type) _type = Line.typeDictionary;
	return _type;
}

- (NSString*)scenesAsJSON
{
	NSMutableArray *scenesToSerialize = NSMutableArray.new;
	NSArray* scenes = self.delegate.parser.scenes.copy;
	
	for (OutlineScene* scene in scenes) {
		[scenesToSerialize addObject:scene.forSerialization];
	}
	
	return scenesToSerialize.json;
}

- (NSString*)outlineAsJSON
{
	NSArray<OutlineScene*>* outline = self.delegate.parser.outline.copy;
	NSMutableArray *scenesToSerialize = [NSMutableArray arrayWithCapacity:outline.count];
	
	/*
	// This is very efficient, but I can't figure out how to fix memory management issues
	 
	NSMutableDictionary<NSNumber*, NSDictionary*>* items = NSMutableDictionary.new;
	
	// Multi-threaded JSON process
	dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
	dispatch_apply((size_t)outline.count, queue, ^(size_t index) {
		if (outline[index] == nil) return;
		NSDictionary* json = outline[index].forSerialization;
		items[@(index)] = json;
	});

	for (NSInteger i=0; i<items.count; i++) {
		NSNumber* idx = @(i);
		if (items[idx] != nil) [scenesToSerialize addObject:items[@(i)]];
	}
	*/
	
	for (OutlineScene* scene in outline) {
		[scenesToSerialize addObject:scene.forSerialization];
	}
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:scenesToSerialize options:0 error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	
	return json;    
}

/// Returns all lines as JSON
- (NSString*)linesAsJSON {
	NSMutableArray *linesToSerialize = NSMutableArray.new;
    NSArray* lines = self.delegate.parser.lines.copy;
    
	for (Line* line in lines) {
        Line* l = line;
        if (!NSThread.mainThread) l = line.clone; // Clone the line for background operations
		
        [linesToSerialize addObject:l.forSerialization];
	}
	
	return linesToSerialize.json;
}

/// Sets given color for the line. Supports both outline elements and lines for the second parameter.
- (void)setColor:(NSString *)color forScene:(id)scene
{
	if ([scene isKindOfClass:OutlineScene.class]) {
		[_delegate.textActions setColor:color forScene:scene];
	} else if ([scene isKindOfClass:Line.class]) {
		[_delegate.textActions setColor:color forLine:scene];
	}
}

- (OutlineScene*)getCurrentScene
{
	return _delegate.currentScene;
}
- (OutlineScene*)getSceneAt:(NSInteger)position
{
    return [_delegate.parser sceneAtPosition:position];
}

- (void)createOutline
{
	[self.delegate.parser updateOutline];
}

- (void)newDocument:(NSString*)string
{
#if !TARGET_OS_IOS
    // This fixes a rare and weird NSResponder issue. Forward this call to the actual document, no questions asked.
    if (![string isKindOfClass:NSString.class]) [self.delegate.document newDocument:nil];
    
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
	if (string.length) [delegate newDocumentWithContents:string];
	else [NSDocumentController.sharedDocumentController newDocument:nil];
#endif
}

- (id)newDocumentObject:(NSString*)string
{
#if !TARGET_OS_IOS
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
	if (string.length) return [delegate newDocumentWithContents:string];
	else return [NSDocumentController.sharedDocumentController openUntitledDocumentAndDisplay:YES error:nil];
#endif
    return nil;
}

- (Line*)currentLine {
	return _delegate.currentLine;
}
- (OutlineScene*)currentScene {
	return _delegate.currentScene;
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
	if (line) [_delegate.formatting formatLine:line];
}
- (void)reformatRange:(NSInteger)loc len:(NSInteger)len {
	[_delegate forceFormatChangesInRange:(NSRange){ loc, len }];
#if !TARGET_OS_IOS
    [_delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
    [_delegate.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
#endif
}


#pragma mark - Temporary attributes

- (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
#if !TARGET_OS_IOS
	NSColor *color = [BeatColors color:hexColor];
	[_delegate.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
#endif
}
- (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len {
#if !TARGET_OS_IOS
    [_delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
#endif
}

- (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
#if TARGET_OS_OSX
	NSColor *color = [BeatColors color:hexColor];
	[self.delegate.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
#endif
}

- (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len {
#if !TARGET_OS_IOS
	[_delegate.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:(NSRange){ loc, len }];
#endif
}


#pragma mark - WebKit controller

- (bool)promisesAvailable {
#if !TARGET_OS_IOS
    if (@available(macOS 11.0, *)) return true;
    else return false;
#else
    return true;
#endif
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
	if ([message.name isEqualToString:@"log"]) {
		[self log:message.body];
	}
    
    // The following methods will require a real JS context, so if it's no longer there, do nothing.
    if (_context == nil) return;
    
	if ([message.name isEqualToString:@"sendData"]) {
		[self receiveDataFromHTMLPanel:message.body];
	}
	else if ([message.name isEqualToString:@"call"]) {
		[_context evaluateScript:message.body];
	}
	else if ([message.name isEqualToString:@"callAndLog"]) {
        [_context evaluateScript:message.body];
        [self log:[NSString stringWithFormat:@"Evaluate: %@", message.body]];
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
- (BeatRevisions*)revisionTracking
{
    return self.delegate.revisionTracking;
}



#pragma mark - Menu items

#if !TARGET_OS_IOS
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
#endif


#pragma mark - Cross-platform compatibility checks

- (NSString*)os {
#if TARGET_OS_IOS
	return @"iOS";
#else
	return @"macOS";
#endif
}

- (bool)iOS {
#if TARGET_OS_IOS
	return true;
#else
	return false;
#endif
}

- (bool)macOS {
	return !self.iOS;
}


@end
/*

 No one is thinking about the flowers
 no one is thinking about the fish
 no one wants
 to believe that the garden is dying
 
 */
