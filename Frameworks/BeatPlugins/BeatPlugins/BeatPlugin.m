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
#import <BeatCore/BeatCore-Swift.h>
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatPlugins/BeatPluginAgent.h>
#import <PDFKit/PDFKit.h>

// Console component
#import "BeatConsole.h"

// Extensions and categories
#import "BeatPlugin+Parser.h"
#import "BeatPlugin+Modals.h"
#import "BeatPlugin+Editor.h"
#import "BeatPlugin+Menus.h"

// Some things are only available on macOS
#if TARGET_OS_OSX
#import "BeatSpeak.h"
#import "BeatHTMLPrinter.h"
#import "BeatModalAccessoryView.h"
#endif


#import <objc/runtime.h>

#if TARGET_OS_IOS
@interface BeatPlugin () <BeatTextChangeObserver>
#else
@interface BeatPlugin () <NSWindowDelegate, PluginWindowHost, BeatTextChangeObserver>
#endif

@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;

@property (nonatomic) BeatPluginData* pluginData;

@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) JSValue *sceneCompletionCallback;
@property (nonatomic) JSValue *characterCompletionCallback;
@property (nonatomic) JSValue *documentSavedCallback;

@property (nonatomic) NSMutableArray *timers;
@property (nonatomic) NSMutableArray *speakSynths;
@property (nonatomic, nullable) JSValue* updateTextMethod;
@property (nonatomic, nullable) JSValue* updateSelectionMethod;
@property (nonatomic, nullable) JSValue* updateOutlineMethod;
@property (nonatomic, nullable) JSValue* updateSceneMethod;
@property (nonatomic, nullable) JSValue* documentDidBecomeMainMethod;
@property (nonatomic, nullable) JSValue* updatePreviewMethod;
@property (nonatomic, nullable) JSValue* escapeMethod;
@property (nonatomic, nullable) JSValue* notepadChangeMethod;

@property (nonatomic) bool terminating;
@property (nonatomic) bool windowClosing;
//@property (nonatomic) bool inCallback;
@property (nonatomic) NSInteger callbacksRemaining;
@property (nonatomic) bool terminateAfterCallback;

@property (nonatomic) NSURL* pluginURL; // URL for a container

@property (nonatomic) NSMutableDictionary<NSValue*, JSValue*>* observedTextViews;


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
	__weak typeof(id<BeatEditorDelegate>) weakDoc = self.delegate;
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
	if (!self.sheet && self.htmlPanel == nil && !self.resident && self.pluginWindows.count < 1 && !self.widgetView && !self.container) {
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
- (void)forceEnd
{
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
#if TARGET_OS_OSX
    if (self.htmlPanel) {
        [self.htmlPanel closePanel:nil];
        self.htmlPanel = nil;
    }
    
    for (BeatPluginHTMLWindow *window in _pluginWindows) {
        // At this point we'll forcibly clear all windows
        window.stayInMemory = false;
        [window closeWindow];
    }
#endif
    [_pluginWindows removeAllObjects];
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
- (void)end
{
	// If end was called in callback, we'll wait until it's done before killing the plugin altogether
    if (self.callbacksRemaining > 0) {
		_terminateAfterCallback = YES;
		return;
	}
	
	_terminating = YES;
	
    // Close all windows and remove them from memory
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
    
    // Clear observers
    [self clearObservables];
	
	self.plugin = nil;
    self.pluginData = nil;
    self.vm = nil;
    self.context = nil;
    
    // Clear all listeners
    self.updateTextMethod = nil;
    self.updateSceneMethod = nil;
    self.updateOutlineMethod = nil;
    self.updatePreviewMethod = nil;
    self.updateSelectionMethod = nil;

    // Remove from the list of running plugins
	if (_resident) [_delegate.pluginAgent deregisterPlugin:self];
}

/// Runs a callback value when a plugin window is closed. We need to finish all callbacks before the plugin itself can be terminated, so we need to jump some extra hoops.
- (void)runCallback:(JSValue*)callback withArguments:(NSArray*)arguments
{
    if (!callback || callback.isUndefined) return;
        
    dispatch_async(dispatch_get_main_queue(), ^{
        // Callback functions are often called when a plugin window is closed, and we can't close the plugin until all callbacks are done.
        // We'll increment remaining callback number, and if it's zero after this callback is done, we'll give permission to terminate the plugin.
        self.callbacksRemaining += 1;
        [callback callWithArguments:arguments];
        self.callbacksRemaining -= 1;
        
        // If we've reached the end of any callbacks, terminate plugin.
        if (self.terminateAfterCallback && self.callbacksRemaining == 0) {
            [self end];
        }
    });
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

// This mess needs an update.
// Make a custom class for listeners, so they can be disabled with changing a property rather than using the endless amounts of booleans (which we're currently doing)

/** Creates a listener for changes in editor text.
 - note:When text is changed, selection will change, too. Avoid creating infinite loops by listening to both changes.
 */
- (void)onTextChange:(JSValue*)updateMethod {
    [self setUpdateText:updateMethod];
}
- (void)setUpdateText:(JSValue *)updateMethod {
	// Save callback
	_updateTextMethod = updateMethod;
	[self makeResident];
}
- (void)updateText:(NSRange)range {
	if (_updateTextMethod == nil || _updateTextMethod.isNull) return;
	if (!self.onTextChangeDisabled) [_updateTextMethod callWithArguments:@[@(range.location), @(range.length)]];
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
	if (_escapeMethod && !_escapeMethod.isNull) [_escapeMethod callWithArguments:nil];
}

- (void)onNotepadChange:(JSValue*)updateMethod {
#if TARGET_OS_OSX
    [self addObservedTextView:(id<BeatTextChangeObservable>)self.delegate.notepad method:updateMethod];
#endif
}

- (void)updateListener:(JSValue*)listener {
    if (listener && !listener.isNull) [listener callWithArguments:nil];
}

/// This is the modern way to observe text changes in *any* objects
- (void)addObservedTextView:(id<BeatTextChangeObservable>)object method:(JSValue*)method
{
    if (_observedTextViews == nil) _observedTextViews = NSMutableDictionary.new;
    NSValue* val = [NSValue valueWithNonretainedObject:object];
    _observedTextViews[val] = method;
    [object addTextChangeObserver:self];
}

- (void)observedTextDidChange:(id<BeatTextChangeObservable>)object
{
    [self.observedTextViews[[NSValue valueWithNonretainedObject:object]] callWithArguments:nil];
}

- (void)clearObservables
{
    for (NSValue* val in _observedTextViews.allKeys) {
        id<BeatTextChangeObservable> object = val.nonretainedObjectValue;
        [object removeTextChangeObserver:self];
    }
    
    [_observedTextViews removeAllObjects];
    _observedTextViews = nil;
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
- (NSArray<NSString*>*)completionsForSceneHeadings {
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
- (NSArray<NSString*>*)completionsForCharacters {
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

- (bool)isMainThread { return NSThread.isMainThread; }


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
- (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats
{
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
- (void)cleanInvalidTimers
{
	NSMutableArray *timers = NSMutableArray.new;
	
	for (int i=0; i < _timers.count; i++) {
		BeatPluginTimer *timer = _timers[i];
		if (timer.isValid) [timers addObject:timer];
	}
	
	_timers = timers;
}

/// Kills all background instances that might have been created by the plugin.
- (void)stopBackgroundInstances
{
	for (BeatPluginTimer *timer in _timers) {
		[timer invalidate];
	}
	[_timers removeAllObjects];
	_timers = nil;
	
    [self killSynths];
}


#pragma mark - Access plugin assets

/// Returns the given file in plugin container as string
- (NSString*)assetAsString:(NSString *)filename
{
	if ([_plugin.files containsObject:filename]) {
		NSString *path = [[BeatPluginManager.sharedManager pathForPlugin:_plugin.name] stringByAppendingPathComponent:filename];
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	} else {
#if TARGET_OS_OSX
        NSString* msg = [NSString stringWithFormat:@"Can't find bundled file '%@' – Are you sure the plugin is contained in a self-titled folder? For example: Plugin.beatPlugin/Plugin.beatPlugin", filename];
		[self log:msg];
		return @"";
#else
        NSLog(@"WARNING: asset as string is trying to find files from app bundle. Remove once done.");
        return [self appAssetAsString:filename];
#endif
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
		if (NSThread.isMainThread) [console logToConsole:string pluginName:(_pluginName != nil) ? _pluginName : @"General" context:self.delegate];
		else {
			// Allow logging in background thread
			dispatch_async(dispatch_get_main_queue(), ^(void){
				[console logToConsole:string pluginName:self.pluginName context:self.delegate];
			});
		}
	#else
		NSLog(@"%@: %@", self.pluginName, string);
	#endif
}

/// Report a plugin error
- (void)reportError:(NSString*)title withText:(NSString*)string
{
    NSString* msg = [NSString stringWithFormat:@"%@ ERROR: %@ (%@)", self.pluginName, title, string];
    [BeatConsole.shared logError:msg context:self pluginName:self.pluginName];
}


#pragma mark - Localization

// Localizes the given string
- (NSString*)localize:(NSString*)string
{
    return [BeatLocalization localizeString:string];
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
            // If the window was already set as full screen, let's not make it appear,
            // because the content size can get wrong on macOS Sonoma
            if (!window.isFullScreen) [window appear];
		}
	}

	/// All plugin windows become normal level windows, so they no longer float above the document window.
	- (void)hideAllWindows
	{
		if (_terminating) return;
		
		for (BeatPluginHTMLWindow *window in self.pluginWindows) {
			[window hideBehindOthers];
		}
	}
#endif


#pragma mark - HTML Window

/**
 HTML view creation accepts different types of arguments as the HTML parameter. Love you, JS.
 You can provide either a single `String`, an array `[htmlContent, headers]` or an object: `{ content: string, headers: string }`. This method converts those arguments into correct format.
 */
- (NSDictionary*)htmlObjectFromValue:(JSValue*)htmlContent
{
    NSMutableDictionary<NSString*, NSString*>* html = NSMutableDictionary.new;
    
    if (htmlContent.isString) {
        html[@"content"] = htmlContent.toString;
    } else if (htmlContent.isArray && htmlContent.toArray.count > 0) {
        NSArray* components = htmlContent.toArray;
        html[@"content"] = components[0];
        if (components.count > 1) html[@"headers"] = components[1];
    } else if (htmlContent.isObject) {
        [html setDictionary:htmlContent.toDictionary];
    }
    
    return html;
}

#if TARGET_OS_OSX

/**
 @param htmlContent The actual content in the window. It's wrapped in a HTML template, so no headers are needed. If you want to provide additional headers, this value can either be an array ([content, headers]) or an object ({ html: "...", headers: "<script></script>" })
 See `htmlObjectFromValue:`.
 */
- (BeatPluginHTMLWindow*)htmlWindow:(JSValue*)htmlContent width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback
{
	// This is a floating window, so the plugin has to be resident
	_resident = YES;
	
    NSDictionary* html = [self htmlObjectFromValue:htmlContent];
    
    NSString* content = html[@"content"];
    NSString* headers = html[@"headers"];
    
	if (width <= 0) width = 500;
	if (width > 1000) width = 1000;
	if (height <= 0) height = 300;
	if (height > 800) height = 800;
	
    BeatPluginHTMLWindow *window = [BeatPluginHTMLWindow.alloc initWithHTML:content width:width height:height headers:headers host:self];
    [self registerPluginWindow:window];
    
    [window makeKeyAndOrderFront:nil];
    window.delegate = self;
    window.callback = callback;
    
    // If no callback is provided, windows will stay in memory by default
    if (callback == nil || [callback isNull] || [callback isUndefined]) window.stayInMemory = true;
	
	return window;
}

/// A plugin (HTML) window will close.
- (void)windowWillClose:(NSNotification *)notification
{
    // ?
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

#else

/// Returns a HTML view controller for iOS. Width and height are disregarded.
- (BeatPluginHTMLViewController*)htmlWindow:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(BOOL)cancelButton
{
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLViewController* htmlVC = [BeatPluginHTMLViewController.alloc initWithHtml:(content) ? content : @"" headers:(headers) ? headers : @""  width:width height:height host:self cancelButton:cancelButton callback:callback];
    [self registerPluginWindow:htmlVC];
        
    UIViewController* documentVC = (UIViewController*)self.delegate;
    [documentVC presentViewController:htmlVC animated:true completion:nil];
     
    return htmlVC;
}

#endif

- (void)registerPluginWindow:(id)window
{
    if (_pluginWindows == nil) {
        _pluginWindows = NSMutableArray.new;
        [_delegate.pluginAgent registerPlugin:self];
    }
    
    [_pluginWindows addObject:window];
#if TARGET_OS_IOS
    [self.delegate registerPluginViewController:window];
#endif
}

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
    if (!window.stayInMemory) [_pluginWindows removeObject:window];
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


#pragma mark - HTML panel
/**
 
 This is a complete mess. Please rewrite sometime soon.
 TODO: Rewrite HTML panel logic and move most of it to another class / category
 
 */

#if TARGET_OS_OSX
- (BeatPluginHTMLPanel*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
    if (_delegate.documentWindow.attachedSheet) return nil;
    
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLPanel* panel = [BeatPluginHTMLPanel.alloc initWithHtml:content headers:(headers) ? headers : @"" width:width height:height host:self cancelButton:cancelButton callback:callback];
    self.htmlPanel = panel;
    
    [self makeResident];
    
    [self.delegate.documentWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
        self.htmlPanel = nil;
    }];
    
    return panel;
}
#else
- (BeatPluginHTMLViewController*)htmlPanel:(JSValue*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton
{
    NSDictionary* htmlContent = [self htmlObjectFromValue:html];
    NSString* content = htmlContent[@"content"];
    NSString* headers = htmlContent[@"headers"];
    
    BeatPluginHTMLViewController* htmlVC = [BeatPluginHTMLViewController.alloc initWithHtml:content headers:headers width:width height:height host:self cancelButton:cancelButton callback:callback];
    
    UIBarButtonItem* button = [UIBarButtonItem.alloc initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(receiveDataFromHTMLPanel:)];
    htmlVC.navigationItem.rightBarButtonItems = @[button];
    
    UINavigationController* nc = [UINavigationController.alloc initWithRootViewController:htmlVC];

    UIViewController* documentVC = (UIViewController*)self.delegate;
    [documentVC presentViewController:nc animated:true completion:nil];
    
    self.htmlPanel = htmlVC;
    return htmlVC;
}
#endif

- (void)receiveDataFromHTMLPanel:(NSString*)json
{
    if (![json isKindOfClass:NSString.class]) json = @"{}";
    
    // This method closes the HTML panel and fetches the results using WebKit message handlers.
    // It is called by sending a message to the script parser via webkit message handler, so this works asynchronously.
    if ([json isEqualToString:@"(null)"]) json = @"{}";
    
    if (self.htmlPanel.callback != nil) {
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        
        JSValue* callback = self.htmlPanel.callback;
        id arguments = @[];
        
        if (!error) {
            arguments = @[jsonData];
        } else {
            [self reportError:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
        }
        
        [self.htmlPanel closePanel:nil];
        [self runCallback:callback withArguments:arguments];
        
        self.htmlPanel.callback = nil;
    } else {
        // If there was no callback, it marks the end of the script
        [self.htmlPanel closePanel:nil];
        [self end];
    }
}


#pragma mark - Tagging interface
// TODO: Just return the tagging object and move all exports there

- (NSArray*)availableTags { return [BeatTagging categories]; }
- (NSDictionary*)tagsForScene:(OutlineScene *)scene { return [self.delegate.tagging tagsForScene:scene]; }


#pragma mark - Pagination interface

/// Legacy compatibility
- (id)paginator:(NSArray*)lines { return self.pagination; }

/// Returns a new pagination object
- (BeatPaginationManager*)pagination
{
	return [BeatPaginationManager.alloc initWithEditorDelegate:self.delegate];
}

/// Returns the current pagination for document
- (BeatPaginationManager*)currentPagination
{
	return self.delegate.pagination;
}

/// Forces the creation of a new pagination at given index
- (void)createPreviewAt:(NSInteger)location {
	[self.delegate createPreviewAt:NSMakeRange(location, 0) sync:true];
}

/// Full reset for preview, which includes both paginating the whole document and rebuilding the layout. Can have a performance hit.
- (void)resetPreview
{
	[self.delegate resetPreview];
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
- (id)objc_call:(NSString*)methodName args:(NSArray*)arguments
{
	Class class = [self.delegate class];
	
	SEL selector = NSSelectorFromString(methodName);
	Method method = class_getClassMethod(class, selector);
	
	char returnType[10];
	method_getReturnType(method, returnType, 10);
	
	if (![self.delegate respondsToSelector:selector]) {
		[self log:[NSString stringWithFormat:@"Unknown selector: %@", methodName]];
		return nil;
	}
	
	NSMethodSignature* signature = [(id)self.delegate methodSignatureForSelector:selector];
	
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
	invocation.target = self.delegate;
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



#pragma mark - Document

/// Creates a new document. macOS-only for now.
- (void)newDocument:(NSString*)string
{
#if TARGET_OS_OSX
    // This fixes a rare and weird NSResponder issue. Forward this call to the actual document, no questions asked.
    if (![string isKindOfClass:NSString.class]) {
        [self.delegate.document newDocument:nil];
        return;
    }
    
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
    if (string.length) [delegate newDocumentWithContents:string];
    else [NSDocumentController.sharedDocumentController newDocument:nil];
#endif
}

/// Creates a new *document object* if you want to access that document after creating it.
- (id)newDocumentObject:(NSString*)string
{
#if !TARGET_OS_IOS
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
    if (string.length) return [delegate newDocumentWithContents:string];
    else return [NSDocumentController.sharedDocumentController openUntitledDocumentAndDisplay:YES error:nil];
#endif
    return nil;
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


#pragma mark - Character data

- (BeatCharacterData*)characterData
{
    return [BeatCharacterData.alloc initWithDelegate:self.delegate];
}


#pragma mark - Formatting

/// Reformats given line in editor.
- (void)reformat:(Line *)line
{
	if (line) [_delegate.formatting formatLine:line];
}
/// Reformats all lines in given range.
- (void)reformatRange:(NSInteger)loc len:(NSInteger)len
{
	[_delegate.formatting forceFormatChangesInRange:(NSRange){ loc, len }];
#if !TARGET_OS_IOS
    // Remove temporary attributes
    [_delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
    [_delegate.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
#endif
}

- (void)setStylesheet:(NSString*)name
{
    [self.delegate setStylesheetAndReformat:name];
}

- (void)resetStyles
{
    [self.delegate resetStyles];
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
	if ([message.name isEqualToString:@"log"]) [self log:message.body];
    
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
    return self.delegate.revisionTracking.revisedRanges;
}
- (BeatRevisions*)revisionTracking
{
    return self.delegate.revisionTracking;
}


#pragma mark - TextView access

#if TARGET_OS_OSX
- (void)setZoomLevel:(CGFloat)zoomLevel
{
    [self.delegate setZoom:zoomLevel];
}
#endif


#pragma mark - Notepad

- (id)notepad { return self.delegate.notepad; }


#pragma mark - Theme manager

@synthesize theme;
- (id)theme { return self.delegate.themeManager; }


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

- (void)addToChangeCount
{
    [self.delegate updateChangeCount:BXChangeDone];
}

@end
/*

 No one is thinking about the flowers
 no one is thinking about the fish
 no one wants
 to believe that the garden is dying
 
 */
