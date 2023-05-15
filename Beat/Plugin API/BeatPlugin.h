//
//  BeatPlugin.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020-2021 Lauri-Matti Parppei. All rights reserved.
//


#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCore.h>
#import "BeatPluginManager.h"

#import <WebKit/WebKit.h>
#import <PDFKit/PDFKit.h>
#import <BeatParsing/BeatParsing.h>

#import "BeatPluginManager.h"
#import "BeatPluginTimer.h"


#if !TARGET_OS_IOS

// macOS-only
#import <Cocoa/Cocoa.h>
#import "NSTextView+UX.h"
#import "BeatPluginHTMLWindow.h"

#import "BeatPluginUIView.h"
#import "BeatPluginUIButton.h"
#import "BeatPluginUIDropdown.h"
#import "BeatPluginUIView.h"
#import "BeatPluginUICheckbox.h"
#import "BeatPluginUILabel.h"

#import "BeatAppDelegate.h"
#import "BeatModalAccessoryView.h"

#import "BeatSpeak.h"
#import "BeatHTMLScript.h"

#import "WebPrinter.h"

#else

// iOS-only
#import <UIKit/UIKit.h>
#import "UITextView+UX.h"

#endif


@class BeatPluginWindow;
@class BeatPreviewController;
@class BeatExportSettings;
@class BeatPluginControlMenu;
@class BeatPluginControlMenuItem;
@class BeatPaginationManager;

@protocol BeatPluginExports <JSExport>
@property (readonly) Line* currentLine;
@property (readonly) OutlineScene* currentScene;
@property (weak, readonly) ContinuousFountainParser *currentParser;

@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;
@property (nonatomic,readonly) NSDictionary *type;

//@property (readonly) NSArray* scenes;
//@property (readonly) NSArray* outline;

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

- (void)log:(NSString*)string;
- (void)openConsole;

- (void)scrollTo:(NSInteger)location;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToLine:(Line*)line;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)scrollToSceneIndex:(NSInteger)index;

- (void)newDocument:(NSString*)string;
- (id)newDocumentObject:(NSString*)string;
- (NSString*)getText;

- (NSPrintInfo*)printInfo;

- (NSArray*)lines;
- (NSArray*)outline;
- (NSArray*)scenes;
- (NSString*)scenesAsJSON;
- (NSString*)outlineAsJSON;
- (NSString*)linesAsJSON;
- (Line*)lineAtPosition:(NSInteger)index;

- (NSRange)selectedRange;
- (NSArray*)linesForScene:(id)scene;
- (NSString*)fileToString:(NSString*)path; /// Read a file into string variable
- (NSString*)pdfToString:(NSString*)path;
- (void)parse;
- (NSString*)assetAsString:(NSString*)filename; /// Plugin bundle asset as string
- (NSString*)appAssetAsString:(NSString*)filename; /// Asset from inside the container
- (void)end;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (NSArray*)availableTags;
- (NSArray*)screen; /// Current screen dimensions
- (NSArray*)windowFrame; /// Window dimensions
- (NSArray*)getWindowFrame; // Alias for windowFrame
- (void)async:(JSValue*)callback; /// Alias for dispatch
- (void)sync:(JSValue*)callback; /// Alias for dispatch_syncb
- (void)dispatch:(JSValue*)callback;
- (void)dispatch_sync:(JSValue*)callback;
- (void)focusEditor;

- (id)getDocumentSetting:(NSString*)key;
- (id)getRawDocumentSetting:(NSString*)key;
- (id)getPropertyValue:(NSString*)key; /// For those who REALLY know what they're doing

- (ContinuousFountainParser*)parser:(NSString*)string;
- (void)createOutline;

/// Returns old-style paginator object
- (BeatPaginationManager*)paginator:(NSArray*)lines;
/// Returns a NEW pagination object
- (BeatPaginationManager*)pagination;
/// Returns the CURRENT pagination in document
- (BeatPaginationManager*)currentPagination;


- (void)reformat:(Line*)line;

- (bool)compatibleWith:(NSString*)version; /// Check compatibility

- (BeatPluginUIView*)widget:(CGFloat)height; /// Add widget into sidebar

/// Move to next tab in document window
- (void)nextTab;
/// Move to previoustab in document window
- (void)previousTab;

- (BeatSpeak*)speakSynth; /// Speech synthesis

/// Restart current plugin
- (void)restart;

/// Ignore this, this is for our office party
- (NSString*)htmlForLines:(NSArray*)lines;

/// Crash the app
- (void)crash;

/// Returns `true` when you can use promises in JS
- (bool)promisesAvailable;

// Revisions
/// Returns all the revised ranges in attributed text
- (NSDictionary*)revisedRanges;
/// Bakes current revisions into lines
- (void)bakeRevisions;
/// Bakes revisions in given range
JSExportAs(bakeRevisionsInRange, - (void)bakeRevisionsInRange:(NSInteger)loc len:(NSInteger)len);

/// Sets a property value in host document. Only for those who REALLY, REALLY, __REALLY__ KNOW WHAT THEY ARE DOING
JSExportAs(setPropertyValue, - (void)setPropertyValue:(NSString*)key value:(id)value);

JSExportAs(setSelectedRange, - (void)setSelectedRange:(NSInteger)start to:(NSInteger)length);
JSExportAs(addString, - (void)addString:(NSString*)string toIndex:(NSUInteger)index);
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string);
JSExportAs(alert, - (void)alert:(NSString*)title withText:(NSString*)info);
JSExportAs(prompt, - (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText);
JSExportAs(confirm, - (bool)confirm:(NSString*)title withInfo:(NSString*)info);
JSExportAs(dropdownPrompt, - (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items);
JSExportAs(setUserDefault, - (void)setUserDefault:(NSString*)settingName setting:(id)value);
JSExportAs(getUserDefault, - (id)getUserDefault:(NSString*)settingName);
JSExportAs(setRawDocumentSetting, - (void)setRawDocumentSetting:(NSString*)settingName setting:(id)value);
JSExportAs(setDocumentSetting, - (void)setDocumentSetting:(NSString*)settingName setting:(id)value);
JSExportAs(openFile, - (void)openFile:(NSArray*)formats callBack:(JSValue*)callback);
JSExportAs(openFiles, - (void)openFiles:(NSArray*)formats callBack:(JSValue*)callback);
JSExportAs(saveFile, - (void)saveFile:(NSString*)format callback:(JSValue*)callback);
JSExportAs(writeToFile, - (bool)writeToFile:(NSString*)path content:(NSString*)content);
JSExportAs(htmlPanel, - (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback cancelButton:(bool)cancelButton);
JSExportAs(htmlWindow, - (NSPanel*)htmlWindow:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback);
JSExportAs(timer, - (BeatPluginTimer*)timerFor:(CGFloat)seconds callback:(JSValue*)callback repeats:(bool)repeats);
JSExportAs(setColorForScene, -(void)setColor:(NSString *)color forScene:(id)scene);
JSExportAs(modal, -(NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback);
JSExportAs(printHTML, - (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback);

// Window interactions
JSExportAs(setWindowFrame, - (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height);

// Text highlights
JSExportAs(textHighlight, - (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(textBackgroundHighlight, - (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeTextHighlight, - (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeBackgroundHighlight, - (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len);
JSExportAs(reformatRange, - (void)reformatRange:(NSInteger)loc len:(NSInteger)len);

// Widget UI
JSExportAs(button, - (BeatPluginUIButton*)button:(NSString*)name action:(JSValue*)action frame:(NSRect)frame);
JSExportAs(dropdown, - (BeatPluginUIDropdown*)dropdown:(NSArray<NSString *> *)items action:(JSValue*)action frame:(NSRect)frame);
JSExportAs(checkbox, - (BeatPluginUICheckbox*)checkbox:(NSString*)title action:(JSValue*)action frame:(NSRect)frame);
JSExportAs(label, - (BeatPluginUILabel*)label:(NSString*)title frame:(NSRect)frame color:(NSString*)color size:(CGFloat)size font:(NSString*)fontName);

// Import/Export
JSExportAs(importHandler, - (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback);
JSExportAs(exportHandler, - (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback);

// Call objective C methods directly
JSExportAs(objc_call, - (id)objc_call:(NSString*)methodName args:(NSArray*)arguments);

// Create a new line element
JSExportAs(line, - (Line*)lineWithString:(NSString*)string type:(LineType)type);

#pragma mark Menu items

- (NSMenuItem*)separatorMenuItem;
- (void)refreshMenus;
JSExportAs(menu, - (BeatPluginControlMenu*)menu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
JSExportAs(menuItem, - (BeatPluginControlMenuItem*)menuItem:(NSString*)title shortcut:(NSArray<NSString*>*)shortcut action:(JSValue*)method);
JSExportAs(submenu, - (NSMenuItem*)submenu:(NSString*)name items:(NSArray<BeatPluginControlMenuItem*>*)items);
@end

// Interfacing with the document
@protocol BeatPluginDelegate <NSObject>

// macOS-only
#if !TARGET_OS_IOS
@property (nonatomic, weak, readonly) NSWindow *documentWindow;
@property (nonatomic, strong) NSMutableArray<BeatPrintView*> *printViews;
@property (nonatomic, readonly) BeatPaginationManager *paginator;
@property (nonatomic, readonly) BeatPreviewController* previewController;
- (void)createPreviewAt:(NSInteger)location;

- (void)addWidget:(id)widget;
- (IBAction)showWidgets:(id)sender;
#endif

@property (nonatomic, readonly, weak) BXTextView *textView;

@property (nonatomic, strong) ContinuousFountainParser *parser;
@property (nonatomic, readonly) BeatTagging *tagging;
@property (nonatomic, readonly) NSPrintInfo *printInfo;
@property (nonatomic, readonly) Line* currentLine;

@property (atomic, readonly) BeatDocumentSettings *documentSettings;
@property (nonatomic, readonly) OutlineScene *currentScene;

@property (nonatomic, readonly) bool closing;

/// Runs a plugin with given name
- (void)runPluginWithName:(NSString*)pluginName;
/// Registers the plugin to stay running in background
- (void)registerPlugin:(id)parser;
/// Removes the plugin from memory
- (void)deregisterPlugin:(id)parser;

/// Sets the given property value in host document. Use only if you *REALLY*, **REALLY** know what the fuck you are doing.
- (void)setPropertyValue:(NSString*)key value:(id)value;
/// Gets a property value from host document.
- (id)getPropertyValue:(NSString*)key;

- (id)document;
- (NSString*)createDocumentFile;
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings;
- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;

- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)removeRange:(NSRange)range;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)setColor:(NSString *)color forScene:(OutlineScene *)scene;
- (void)setColor:(NSString *)color forLine:(Line *)line;

- (void)focusEditor;

- (NSString*)text;
- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position;

- (void)forceFormatChangesInRange:(NSRange)range;
- (void)formatLine:(Line*)line;

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

@interface BeatPlugin : NSObject <BeatPluginExports, WKScriptMessageHandler, NSWindowDelegate, PluginWindowHost, WKScriptMessageHandlerWithReply>
@property (weak) id<BeatPluginDelegate> delegate;
@property (weak, nonatomic) ContinuousFountainParser *currentParser;
@property (nonatomic) NSString* pluginName;

@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;

@property (nonatomic) NSArray* exportedExtensions;
@property (nonatomic) NSArray* importedExtensions;
@property (nonatomic) JSValue* importCallback;
@property (nonatomic) JSValue* exportCallback;

- (void)loadPlugin:(BeatPluginData*)plugin;
- (void)log:(NSString*)string;
- (void)update:(NSRange)range;
- (void)updateSelection:(NSRange)selection;
- (void)updateOutline:(NSArray*)outline;
- (void)updateSceneIndex:(NSInteger)sceneIndex;
- (void)previewDidFinish:(NSIndexSet*)changedIndices;
- (void)closePluginWindow:(NSPanel*)window;
- (void)forceEnd;
- (void)documentDidBecomeMain;
- (void)documentDidResignMain;
- (void)documentWasSaved;
- (void)escapePressed;


// Autocompletion callbacks
- (NSArray*)completionsForSceneHeadings; /// Called if the resident plugin has a callback for scene heading autocompletion
- (NSArray*)completionsForCharacters; /// Called if the resident plugin has a callback for character cue autocompletion

- (void)showAllWindows;
- (void)hideAllWindows;

- (void)restart;

- (void)refreshMenus;


@end
