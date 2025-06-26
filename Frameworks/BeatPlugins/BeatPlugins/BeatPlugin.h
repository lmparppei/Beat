//
//  BeatPlugin.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020-2021 Lauri-Matti Parppei. All rights reserved.
//


#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCore.h>
#import <BeatPlugins/BeatPluginManager.h>

#import <WebKit/WebKit.h>
#import <PDFKit/PDFKit.h>
#import <BeatParsing/BeatParsing.h>

#import <BeatPlugins/BeatPluginManager.h>
#import <BeatPlugins/BeatPluginTimer.h>


#if TARGET_OS_OSX

// macOS-only
#import <Cocoa/Cocoa.h>
#import <BeatPlugins/BeatPluginHTMLWindow.h>
@class BeatPluginHTMLPanel;
@class BeatHTMLPrinter;
@class BeatPluginData;

#else

// iOS-only
#import <UIKit/UIKit.h>
@class BeatPluginHTMLViewController;

#endif


@class BeatPluginWindow;
@class BeatPreviewController;
@class BeatExportSettings;
@class BeatPluginControlMenu;
@class BeatPluginControlMenuItem;
@class BeatPaginationManager;
@class BeatPagination;
@class OutlineScene;
@class BeatTextIO;
@class BeatSpeak;

@class BeatPluginAgent;

@class BeatPluginUIView;
@class BeatPluginUIButton;
@class BeatPluginUIDropdown;
@class BeatPluginUICheckbox;
@class BeatPluginUILabel;

@protocol BeatPluginContainer;
@protocol BeatHTMLView;

#pragma mark - App delegate replacement

@protocol BeatAppAPIDelegate
- (id)newDocumentWithContents:(NSString*)string;
@end

#pragma mark - JS API exports

@protocol BeatPluginExports <JSExport>

#pragma mark Plugin control
/// Stop plugin execution
- (void)end;
/// Restart current plugin
- (void)restart;
/// Crash the app
- (void)crash;
/// Container view for this plugin (if applicable)
@property (weak, readonly, nonatomic) id<BeatPluginContainer> container;

#if TARGET_OS_OSX
- (id)document;
- (void)setZoomLevel:(CGFloat)zoomLevel;
#endif


#pragma mark System access
/// Check compatibility with Beat version. Basically used for checking if Beat version is out of date.
- (bool)compatibleWith:(NSString*)version;

/// Sets a property value in host document. Only for those who REALLY, REALLY, __REALLY__ KNOW WHAT THEY ARE DOING
JSExportAs(setPropertyValue, - (void)setPropertyValue:(NSString*)key value:(id)value);
/// Executes a run-time ObjC call. This is for the people who, really, and let me emphasize, __actually__ know what the fuck they are doing. No plugins should ever use this method. Purely for testing and hacking purposes.
JSExportAs(objc_call, - (id)objc_call:(NSString*)methodName args:(NSArray*)arguments);
/// Returns `true` when the plugin is running on iOS
- (bool)iOS;
/// Returns `true` when the plugin is running on macOS
- (bool)macOS;
/// Returns a string, with all instances of `#key#` replaced with localized strings.
- (NSString*)localize:(NSString*)string;


#pragma mark Document settings
/// Returns a document setting prefixed by current plugin name
- (id)getDocumentSetting:(NSString*)key;
/// Returns a non-prefixed document setting
- (id)getRawDocumentSetting:(NSString*)key;
/// For those who REALLY know what they're doing
- (id)getPropertyValue:(NSString*)key;
/// Sets a document setting without plugin prefix. Can be used to tweak actual document data.
JSExportAs(setRawDocumentSetting, - (void)setRawDocumentSetting:(NSString*)settingName setting:(id)value);
/// Sets a document setting, prefixed by plugin name, so you won't mess up settings for other plugins.
JSExportAs(setDocumentSetting, - (void)setDocumentSetting:(NSString*)settingName setting:(id)value);

#pragma mark User settings
/// Sets a user default (`key`, `value`)
JSExportAs(setUserDefault, - (void)setUserDefault:(NSString*)settingName setting:(id)value);
/// Returns a user default (`key`)
JSExportAs(getUserDefault, - (id)getUserDefault:(NSString*)settingName);


#pragma mark Listeners
@property (nonatomic) bool onPreviewFinishedDisabled;
@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;

/// Forces the plugin to stay in memory
- (void)makeResident;


#pragma mark General editor and app access
/// Creates a new document with given string
/// - note: The string can contain a settings block
- (void)newDocument:(NSString*)string;
/// Creates a new `Document` object without actually opening the window
- (id)newDocumentObject:(NSString*)string;
/// Returns the (shared) theme manager
@property (nonatomic, weak) id theme;

/// Current screen dimensions
- (NSArray*)screen;

	#if !TARGET_OS_IOS
	/// Window dimensions
	- (NSArray*)windowFrame;
	/// Alias for windowFrame
	- (NSArray*)getWindowFrame;
	/// Sets the window frame
	JSExportAs(setWindowFrame, - (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height);
	#endif


#pragma mark Logging
/// Logs given string in developer console
- (void)log:(NSString*)string;
/// Opens the console programmatically
- (void)openConsole;



#pragma mark - Document utilities

/// Returns the plain-text file content used to save current screenplay (including settings block etc.)
- (NSString*)createDocumentFile;
/// Returns the plain-text file content used to save current screenplay (including settings block etc.) with additional `BeatDocumentSettings` block
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings;

#if TARGET_OS_OSX
/// Returns all document instances
- (NSArray<id>*)documents;
/// Returns a plugin interface for given document
- (id)interface:(id)document;
#endif

#pragma mark Tagging
/// Returns all tags in the scene
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
/// Returns all available tag names
- (NSArray*)availableTags;


#pragma mark Multi-threading
/// Dispatch a block into a background thread
- (void)async:(JSValue*)callback;
/// Dispatch a block into the main thread
- (void)sync:(JSValue*)callback;
/// Alias for async
- (void)dispatch:(JSValue*)callback;
/// Alias for sync
- (void)dispatch_sync:(JSValue*)callback;
/// Returns `true` if the current operation happens in main thread
- (bool)isMainThread;


#pragma mark Pagination
/// Sets a stylesheet and reformats the document
- (void)setStylesheet:(NSString*)name;
/// Returns the CURRENT pagination manager in document
- (BeatPaginationManager*)currentPagination;
/// Creates and returns a new pagination manager with given lines as input
- (BeatPaginationManager*)paginator:(NSArray*)lines;
/// Creates and returns a NEW pagination manager
- (BeatPaginationManager*)pagination;
/// Resets the preview and clears pagination
- (void)resetPreview;
- (void)resetStyles;

#pragma mark Reformatting
JSExportAs(reformatRange, - (void)reformatRange:(NSInteger)loc len:(NSInteger)len);
- (void)reformat:(Line*)line;


#pragma mark Speak synthesizer
#if !TARGET_OS_IOS
/// Create new speech synthesis instance
- (BeatSpeak*)speakSynth;
#endif


#pragma mark Timer
JSExportAs(timer, - (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats);


#pragma mark Revisions
@property (nonatomic) BeatRevisions* revisionTracking;
/// Returns all the revised ranges in attributed text
- (NSDictionary*)revisedRanges;
/// Bakes current revisions into lines
- (void)bakeRevisions;
/// Bakes revisions in given range
JSExportAs(bakeRevisionsInRange, - (void)bakeRevisionsInRange:(NSInteger)loc len:(NSInteger)len);


#pragma mark Character data
/// Returns character data object
- (BeatCharacterData*)characterData;



#pragma mark Notepad
#if TARGET_OS_OSX
@property (nonatomic, weak, readonly) BeatNotepad* notepad;
#endif

#pragma mark Import / export plugin handlers
JSExportAs(importHandler, - (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback);
JSExportAs(exportHandler, - (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback);


@end


#pragma mark - Host document delegate

@protocol BeatPluginDelegate <BeatEditorDelegate>

#if !TARGET_OS_IOS
    // macOS-only
    @property (nonatomic, readonly) BeatPaginationManager *paginator;
    @property (nonatomic, readonly) BeatPreviewController* previewController;
    @property (nonatomic, readonly) NSPrintInfo *printInfo;
    @property (nonatomic, weak, readonly) NSWindow *documentWindow;
    @property (nonatomic, weak) BeatNotepad* notepad;

    /// Returns the file name without extension
    - (NSString*)fileNameString;
    /// Adds a widget view
    - (void)addWidget:(id)widget;
    /// Shows widget panel
    - (IBAction)showWidgets:(id)sender;
    /// Sets current zoom level
    - (void)setZoom:(CGFloat)zoomLevel;
#else
    // iOS-only
    @property (nonatomic, weak, readonly) UIWindow *documentWindow;
#endif

@property (nonatomic, readonly, weak) BXTextView *textView;

#pragma mark - Plugin container access

- (void)registerPluginContainer:(id<BeatPluginContainer>)view;
#if TARGET_OS_IOS
- (void)registerPluginViewController:(BeatPluginHTMLViewController*)view;
- (void)unregisterPluginViewController:(BeatPluginHTMLViewController*)view;
#endif


#pragma mark - Preview and pagination access

- (void)createPreviewAt:(NSRange)range;
- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync;


#pragma mark - Getter and setter for main document controller class

/// Sets the given property value in host document. Use only if you *REALLY*, **REALLY** know what the fuck you are doing.
- (void)setPropertyValue:(NSString*)key value:(id)value;
/// Gets a property value from host document.
- (id)getPropertyValue:(NSString*)key;

- (NSString*)createDocumentFile;
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings;


#pragma mark - Scrolling

- (void)scrollTo:(NSInteger)location;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToSceneIndex:(NSInteger)index;


#pragma mark - Screenplay data

/// Revision manager
@property (nonatomic) BeatRevisions* revisionTracking;
@end



#pragma mark - PLUGIN INTERFACE

@interface BeatPlugin: NSObject <BeatPluginExports>
#pragma mark - Class method helers

+ (BeatPlugin*)withName:(NSString*)name delegate:(id<BeatPluginDelegate>)delegate;
+ (BeatPlugin*)withName:(NSString*)name script:(NSString*)script delegate:(id<BeatPluginDelegate>)delegate;

#pragma mark - Plugin metadata

@property (nonatomic) BeatPluginData *plugin;
@property (nonatomic) NSURL* pluginURL;

#pragma mark - The actual JS environment

@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;


#pragma mark - Functional flags

/// Set `true` if the plugin should stay in memory and not terminate immediately after initial code was run.
@property (nonatomic) bool resident;
/// Set  `true` when the plugin is inside a termination sequence
@property (nonatomic) bool terminating;
/// A window is currently closing
@property (nonatomic) bool windowClosing;
/// The plugin is terminating, but there are callbacks remaining, this value is the amount of callbakcs that need to be run until we can actually terminate the process
@property (nonatomic) NSInteger callbacksRemaining;
/// Set `true` when the plugin can be safely closed after this callback
@property (nonatomic) bool terminateAfterCallback;


#pragma mark - Essential properties

@property (weak) id<BeatPluginDelegate> delegate;
@property (nonatomic) ContinuousFountainParser *currentParser;
@property (nonatomic) NSString* pluginName;

/// Set `true` if the plugin should be restored when document is opened. (Default is `true`)
@property (nonatomic) bool restorable;


/// Type dictionary for plugins
@property (nonatomic) NSDictionary *type;

@property (weak, nonatomic) id<BeatPluginContainer> container;

@property (nonatomic) bool onPreviewFinishedDisabled;
@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;

@property (nonatomic) NSArray* exportedExtensions;
@property (nonatomic) NSArray* importedExtensions;
@property (nonatomic) JSValue* importCallback;
@property (nonatomic) JSValue* exportCallback;

@property (nonatomic) NSMutableArray *pluginWindows;

/// Getter for revision tracking in delegate
@property (nonatomic) BeatRevisions* revisionTracking;


#pragma mark UI-side stuff for macOS and iOS

#if TARGET_OS_OSX
@property (nonatomic) BeatHTMLPrinter *printer;
@property (nonatomic) NSMutableArray<NSMenuItem*>* menus;
@property (nonatomic) BeatPluginUIView *widgetView;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) BeatPluginHTMLPanel* htmlPanel;
#else
@property (nonatomic) id<BeatHTMLView> htmlPanel;
@property (nonatomic) UIWindow *sheet;
@property (nonatomic) id widgetView;
#endif


#pragma mark Base plugin instance methods

- (void)loadPluginWithName:(NSString*)name;
- (void)loadPlugin:(BeatPluginData*)plugin;
- (void)log:(NSString*)string;
- (void)reportError:(NSString*)title withText:(NSString*)string;
- (void)forceEnd;

- (void)runCallback:(JSValue*)callback withArguments:(NSArray*)arguments;

- (void)addToChangeCount;

/// Custom error handler
-(void)replaceErrorHandler:(void (^)(JSValue* exception))block;

/// Runs given script in the plugin context
- (JSValue*)call:(NSString*)script;


#pragma mark Listeners

@property (nonatomic) JSValue* updateTextMethod;
@property (nonatomic) JSValue* updateSelectionMethod;
@property (nonatomic) JSValue* updateOutlineMethod;
@property (nonatomic) JSValue* updateSceneMethod;
@property (nonatomic) JSValue* documentDidBecomeMainMethod;
@property (nonatomic) JSValue* updatePreviewMethod;
@property (nonatomic) JSValue* escapeMethod;
@property (nonatomic) JSValue* notepadChangeMethod;
@property (nonatomic) JSValue* documentSavedCallback;


#pragma mark Other callbacks and data providers

@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) JSValue *windowCallback;
@property (nonatomic) JSValue *sceneCompletionCallback;
@property (nonatomic) JSValue *characterCompletionCallback;


#pragma mark Observed text views

@property (nonatomic) NSMutableDictionary<NSValue*, JSValue*>* observedTextViews;

- (void)restart;


@end
