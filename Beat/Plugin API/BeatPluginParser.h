//
//  BeatScriptParser.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginManager.h"
#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"
#import "BeatTagging.h"
#import "TagDefinition.h"
//#import "BeatPluginWindow.h"
#import "BeatPaginator.h"
#import "BeatPluginTimer.h"
#import "BeatHTMLPanel.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <WebKit/WebKit.h>

@class BeatPluginWindow;

@protocol BeatScriptingExports <JSExport>
@property (readonly) Line* currentLine;
@property (weak, readonly) ContinuousFountainParser *currentParser;

@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;

//@property (readonly) NSArray* scenes;
//@property (readonly) NSArray* outline;

// Alias + actual methods for update methods
- (void)setUpdate:(JSValue*)updateMethod;
- (void)onTextChange:(JSValue*)updateMethod;
- (void)setSelectionUpdate:(JSValue *)updateMethod;
- (void)onSelectionChange:(JSValue*)updateMethod;
- (void)onOutlineChange:(JSValue*)updateMethod;
- (void)onSceneIndexUpdate:(JSValue*)updateMethod;

- (void)log:(NSString*)string;
- (void)openConsole;
- (void)scrollTo:(NSInteger)location;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToLine:(Line*)line;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)scrollToSceneIndex:(NSInteger)index;
- (void)newDocument:(NSString*)string;
- (NSString*)getText;

- (NSArray*)lines;
- (NSArray*)outline;
- (NSArray*)scenes;
- (NSString*)scenesAsJSON;
- (NSString*)outlineAsJSON;
- (NSString*)linesAsJSON;

- (NSRange)selectedRange;
- (NSArray*)linesForScene:(id)scene;
- (NSString*)fileToString:(NSString*)path;
- (NSString*)pdfToString:(NSString*)path;
- (void)parse;
- (NSString*)assetAsString:(NSString*)filename;
- (NSString*)appAssetAsString:(NSString*)filename;
- (void)end;
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
- (NSArray*)availableTags;
- (NSArray*)screen;
- (void)dispatch:(JSValue*)callback;
- (void)dispatch_sync:(JSValue*)callback;
- (void)focusEditor;

- (ContinuousFountainParser*)parser:(NSString*)string;

- (BeatPaginator*)paginator:(NSArray*)lines;

- (void)reformat:(Line*)line;
- (void)reformatRange:(NSInteger)loc len:(NSInteger)len;

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
JSExportAs(setColorForScene, -(void)setColor:(NSString *)color forScene:(OutlineScene *)scene);
JSExportAs(modal, -(NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback);
JSExportAs(textHighlight, - (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(textBackgroundHighlight, - (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);

JSExportAs(removeTextHighlight, - (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeBackgroundHighlight, - (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len);

@end

// Interfacing with the document
@protocol BeatScriptingDelegate <NSObject>
@property (nonatomic, strong, nonatomic) ContinuousFountainParser *parser;
@property (nonatomic, weak, readonly) NSWindow *thisWindow;
@property (nonatomic, readonly) BeatTagging *tagging;
@property (nonatomic, readonly) NSPrintInfo *printInfo;
@property (nonatomic, readonly) Line* currentLine;
@property (nonatomic, readonly, weak) NSTextView *textView;
@property (atomic, readonly) BeatDocumentSettings *documentSettings;

- (void)registerPlugin:(id)parser;
- (void)deregisterPlugin:(id)parser;
- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;
- (void)scrollTo:(NSInteger)location;
- (void)scrollToLine:(Line*)line;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToSceneIndex:(NSInteger)index;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)removeRange:(NSRange)range;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)setColor:(NSString *)color forScene:(OutlineScene *)scene;
- (void)focusEditor;
- (NSString*)getText;
- (OutlineScene*)getCurrentScene;
- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position;
- (void)forceFormatChangesInRange:(NSRange)range;
- (void)formatLineOfScreenplay:(Line*)line;
@end

@interface BeatPluginParser : NSObject <BeatScriptingExports, WKScriptMessageHandler, NSWindowDelegate, PluginWindowHost>
@property (weak) id<BeatScriptingDelegate> delegate;
@property (weak, nonatomic) ContinuousFountainParser *currentParser;
@property (nonatomic) NSString* pluginName;

@property (nonatomic) bool onOutlineChangeDisabled;
@property (nonatomic) bool onSelectionChangeDisabled;
@property (nonatomic) bool onTextChangeDisabled;
@property (nonatomic) bool onSceneIndexUpdateDisabled;

- (void)loadPlugin:(BeatPlugin*)plugin;
- (void)log:(NSString*)string;
- (void)update:(NSRange)range;
- (void)updateSelection:(NSRange)selection;
- (void)updateOutline:(NSArray*)outline;
- (void)updateSceneIndex:(NSInteger)sceneIndex;
- (void)closePluginWindow:(NSPanel*)window;
- (void)forceEnd;
@end
