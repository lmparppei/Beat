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

#else

// iOS-only
#import <UIKit/UIKit.h>

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

#pragma mark System access
/// Check compatibility with Beat version. Basically used for checking if Beat version is out of date.
- (bool)compatibleWith:(NSString*)version;
/// Returns `true` when you can use promises in JS
- (bool)promisesAvailable;
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

#pragma mark Parsed content
/// List of Beat line types
@property (nonatomic,readonly) NSDictionary *type;
/// Returns the actual parser object in the document
@property (weak, readonly) ContinuousFountainParser *currentParser;

/// Create a new parser with given raw string (__NOTE__: Doesn't support document settings, revisions, etc.)
- (ContinuousFountainParser*)parser:(NSString*)string;

/// Returns all parsed lines
- (NSArray*)lines;
/// Returns the current outline
- (NSArray*)outline;
/// Returns the current outline excluding any structural elements (namely `sections`)
- (NSArray*)scenes;

/// Returns the full outline as a JSON string
- (NSString*)outlineAsJSON;
/// Returns all scenes as a JSON string
- (NSString*)scenesAsJSON;
/// Returns all lines as a JSON string
- (NSString*)linesAsJSON;
/// Returns the line at given position in document
- (Line*)lineAtPosition:(NSInteger)index;
/// Returns the scene at given position in document
- (Line*)sceneAtPosition:(NSInteger)index;
/// Returns lines in given scene.
- (NSArray*)linesForScene:(OutlineScene*)scene;
/// Creates the outline from scratch
- (void)createOutline;
/// Returns the full raw text (excluding settings block)
- (NSString*)getText;
/// Creates a new line element
JSExportAs(line, - (Line*)lineWithString:(NSString*)string type:(LineType)type);


#pragma mark Contextual line and scene info
/// Currently edited line
@property (readonly) Line* currentLine;
/// Currently edited scene
@property (readonly) OutlineScene* currentScene;


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

// Alias + actual methods for update methods
- (void)setUpdate:(JSValue*)updateMethod;
- (void)onTextChange:(JSValue*)updateMethod;

- (void)setSelectionUpdate:(JSValue *)updateMethod;
- (void)onSelectionChange:(JSValue*)updateMethod;

- (void)onOutlineChange:(JSValue*)updateMethod;
- (void)onSceneIndexUpdate:(JSValue*)updateMethod;

- (void)onDocumentBecameMain:(JSValue*)updateMethod;
- (void)onSceneHeadingAutocompletion:(JSValue*)callback;
- (void)onCharacterAutocompletion:(JSValue*)callback;
- (void)onPreviewFinished:(JSValue*)updateMethod;
- (void)onPaginationFinished:(JSValue*)updateMethod;
- (void)onDocumentSaved:(JSValue*)updateMethod;
- (void)onEscape:(JSValue*)updateMethod;


#pragma mark General editor and app access
/// Creates a new document with given string
/// - note: The string can contain a settings block
- (void)newDocument:(NSString*)string;
/// Creates a new `Document` object without actually opening the window
- (id)newDocumentObject:(NSString*)string;


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


#pragma mark Editor view
/// Focuses the editor text view
- (void)focusEditor;

/// Scrolls to given position in document
- (void)scrollTo:(NSInteger)location;
/// Scrolls to given line index
- (void)scrollToLineIndex:(NSInteger)index;
/// Scrolls to given line
- (void)scrollToLine:(Line*)line;
/// Scrolls to given scene heading
- (void)scrollToScene:(OutlineScene*)scene;
/// Scrolls to the scene heading at given outline index
- (void)scrollToSceneIndex:(NSInteger)index;
/// Returns the selected range in editor
- (NSRange)selectedRange;

/// Move to next tab in document window
- (void)nextTab;
/// Move to previoustab in document window
- (void)previousTab;


#pragma mark File I/O
/// Read any (text) file into string variable
- (NSString*)fileToString:(NSString*)path;
/// Read a PDF file into string variable
- (NSString*)pdfToString:(NSString*)path;
/// Plugin bundle asset as string
- (NSString*)assetAsString:(NSString*)filename;
/// Asset from inside the app container
- (NSString*)appAssetAsString:(NSString*)filename;
/// Write a string to file in given path. You can't access files unless they are in the container or user explicitly selected them using a save dialog.
JSExportAs(writeToFile, - (bool)writeToFile:(NSString*)path content:(NSString*)content);

#if !TARGET_OS_IOS
    /// Displays an open dialog
    JSExportAs(openFile, - (void)openFile:(NSArray*)formats callBack:(JSValue*)callback);
    /// Displays an open dialog with the option to select multiple files
    JSExportAs(openFiles, - (void)openFiles:(NSArray*)formats callBack:(JSValue*)callback);
    /// Displays a save dialog
    JSExportAs(saveFile, - (void)saveFile:(NSString*)format callback:(JSValue*)callback);

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
/// Returns the CURRENT pagination manager in document
- (BeatPaginationManager*)currentPagination;
/// Creates and returns a new pagination manager with given lines as input
- (BeatPaginationManager*)paginator:(NSArray*)lines;
/// Creates and returns a NEW pagination manager
- (BeatPaginationManager*)pagination;
/// Resets the preview and clears pagination
- (void)resetPreview;

#pragma mark Reformatting
JSExportAs(reformatRange, - (void)reformatRange:(NSInteger)loc len:(NSInteger)len);
- (void)reformat:(Line*)line;


#pragma mark Widgets (macOS only)
#if !TARGET_OS_IOS
	/// Add widget into sidebar
	- (BeatPluginUIView*)widget:(CGFloat)height;
	JSExportAs(button, - (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame);
	JSExportAs(dropdown, - (BeatPluginUIDropdown*)dropdown:(NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame);
	JSExportAs(checkbox, - (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame);
	JSExportAs(label, - (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName);
#endif


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


#pragma mark Text I/O

JSExportAs(setSelectedRange, - (void)setSelectedRange:(NSInteger)start to:(NSInteger)length);
JSExportAs(addString, - (void)addString:(NSString*)string toIndex:(NSUInteger)index);
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string);
JSExportAs(setColorForScene, -(void)setColor:(NSString *)color forScene:(id)scene);


#pragma mark Modal windows
/// Displays a simple modal alert box
JSExportAs(alert, - (void)alert:(NSString*)title withText:(NSString*)info);
/// Displays a text input prompt.
/// - returns String value. Value is `nil` if the user pressed cancel.
JSExportAs(prompt, - (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText);
/// Displays a confirmation modal. Returns `true` if the user pressed OK.
JSExportAs(confirm, - (bool)confirm:(NSString*)title withInfo:(NSString*)info);
/// Displays a dropdown prompt with a list of strings. Returns the selected string. Return value is `nil` if the user pressed cancel.
JSExportAs(dropdownPrompt, - (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items);
/// Displays a modal with given settings. Consult the wiki for correct dictionary keys and values.
JSExportAs(modal, -(NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback);

#pragma mark Displaying HTML content
#if !TARGET_OS_IOS
	JSExportAs(htmlPanel, - (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton);
	JSExportAs(htmlWindow, - (NSPanel*)htmlWindow:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback);
    - (NSDictionary*)printInfo;
    JSExportAs(printHTML, - (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback);
#endif


#pragma mark Text highlighting
JSExportAs(textHighlight, - (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(textBackgroundHighlight, - (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeTextHighlight, - (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeBackgroundHighlight, - (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len);


#pragma mark Import / export plugin handlers
JSExportAs(importHandler, - (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback);
JSExportAs(exportHandler, - (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback);


#pragma mark Menu items (macOS only)
#if !TARGET_OS_IOS
	- (NSMenuItem*)separatorMenuItem;
	- (void)refreshMenus;
	JSExportAs(menu, - (BeatPluginControlMenu*)menu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
	JSExportAs(menuItem, - (BeatPluginControlMenuItem*)menuItem:(NSString*)title shortcut:(NSArray<NSString*>*)shortcut action:(JSValue*)method);
	JSExportAs(submenu, - (NSMenuItem*)submenu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
    - (id)document;
#endif
@end


#pragma mark - Host document delegate

@protocol BeatPluginDelegate <BeatEditorDelegate>

// macOS-only
#if !TARGET_OS_IOS
@property (nonatomic, readonly) BeatPaginationManager *paginator;
@property (nonatomic, readonly) BeatPreviewController* previewController;
@property (nonatomic, readonly) NSPrintInfo *printInfo;

/// Returns the file name without extension
- (NSString*)displayName;

- (void)addWidget:(id)widget;
- (IBAction)showWidgets:(id)sender;
@property (nonatomic, weak, readonly) NSWindow *documentWindow;
#else
@property (nonatomic, weak, readonly) UIWindow *documentWindow;
#endif

@property (nonatomic, readonly, weak) BXTextView *textView;

@property (nonatomic, strong) ContinuousFountainParser *parser;
@property (nonatomic, readonly) BeatTagging *tagging;
@property (nonatomic, readonly) Line* currentLine;

@property (nonatomic, readonly) OutlineScene *currentScene;

@property (nonatomic) BeatRevisions* revisionTracking;

- (void)registerPluginContainer:(id<BeatPluginContainer>)view;
- (BeatPaginationManager*)pagination;
- (void)createPreviewAt:(NSRange)range;
- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync;
- (void)resetPreview;

@property (nonatomic) BeatPluginAgent* pluginAgent;

/*
/// Runs a plugin with given name
- (void)runPluginWithName:(NSString*)pluginName;
/// Registers the plugin to stay running in background
- (void)registerPlugin:(id)parser;
/// Removes the plugin from memory
- (void)deregisterPlugin:(id)parser;
 */

/// Sets the given property value in host document. Use only if you *REALLY*, **REALLY** know what the fuck you are doing.
- (void)setPropertyValue:(NSString*)key value:(id)value;
/// Gets a property value from host document.
- (id)getPropertyValue:(NSString*)key;

- (id)document;
- (NSString*)createDocumentFile;
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings;

- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;

- (void)focusEditor;

- (NSString*)text;

- (void)forceFormatChangesInRange:(NSRange)range;

- (NSDictionary*)revisedRanges; /// Returns all the revised ranges in attributed text
- (void)bakeRevisions; /// Bakes current revisions into lines
- (NSAttributedString*)getAttributedText;

- (void)scrollTo:(NSInteger)location;
- (void)scrollToLine:(Line*)line;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToSceneIndex:(NSInteger)index;
- (void)scrollToScene:(OutlineScene*)scene;

- (BeatExportSettings*)exportSettings;

- (NSLayoutManager*)layoutManager;
- (NSTextStorage*)textStorage;

@end

@interface BeatPlugin : NSObject <BeatPluginInstance, BeatPluginExports, WKScriptMessageHandler, WKScriptMessageHandlerWithReply>
+ (BeatPlugin*)withName:(NSString*)name delegate:(id<BeatPluginDelegate>)delegate;
+ (BeatPlugin*)withName:(NSString*)name script:(NSString*)script delegate:(id<BeatPluginDelegate>)delegate;

@property (weak) id<BeatPluginDelegate> delegate;
@property (weak, nonatomic) ContinuousFountainParser *currentParser;
@property (nonatomic) NSString* pluginName;
@property (readonly) NSURL* pluginURL;
@property (nonatomic) bool restorable;

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

/// Getter for revision tracking in delegate
@property (nonatomic) BeatRevisions* revisionTracking;

- (void)loadPluginWithName:(NSString*)name;
- (void)loadPlugin:(BeatPluginData*)plugin;
- (void)log:(NSString*)string;
- (void)reportError:(NSString*)title withText:(NSString*)string;
- (void)update:(NSRange)range;
- (void)updateSelection:(NSRange)selection;
- (void)updateOutline:(OutlineChanges*)changes;
- (void)updateSceneIndex:(NSInteger)sceneIndex;
- (void)previewDidFinish:(BeatPagination*)pagination indices:(NSIndexSet*)changedIndices;
- (void)closePluginWindow:(id)window;
- (void)forceEnd;
- (void)documentDidBecomeMain;
- (void)documentDidResignMain;
- (void)documentWasSaved;
- (void)escapePressed;

- (void)runCallback:(JSValue*)callback withArguments:(NSArray*)arguments;

/// Custom error handler
-(void)replaceErrorHandler:(void (^)(JSValue* exception))block;

/// Runs given script in the plugin context
- (JSValue*)call:(NSString*)script;

// Autocompletion callbacks
- (NSArray*)completionsForSceneHeadings; /// Called if the resident plugin has a callback for scene heading autocompletion
- (NSArray*)completionsForCharacters; /// Called if the resident plugin has a callback for character cue autocompletion

#if !TARGET_OS_IOS
- (void)showAllWindows;
- (void)hideAllWindows;
- (void)refreshMenus;
#endif

- (void)restart;



@end
