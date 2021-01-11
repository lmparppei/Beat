//
//  BeatScriptParser.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatScriptingExports <JSExport>
- (void)log:(NSString*)string;
- (void)scrollTo:(NSInteger)location;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)scrollToSceneIndex:(NSInteger)index;
- (void)newDocument:(NSString*)string;
- (NSString*)getText;
- (NSArray*)lines;
- (NSArray*)outline;
- (NSArray*)scenes;
- (NSRange)selectedRange;
- (NSArray*)linesForScene:(id)scene;
- (NSString*)fileToString:(NSString*)path;
- (NSString*)pdfToString:(NSString*)path;
- (void)parse;

JSExportAs(setSelectedRange, - (void)setSelectedRange:(NSInteger)start to:(NSInteger)length);
JSExportAs(addString, - (void)addString:(NSString*)string toIndex:(NSUInteger)index);
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string);
JSExportAs(alert, - (void)alert:(NSString*)title withText:(NSString*)info);
JSExportAs(prompt, - (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText);
JSExportAs(confirm, - (bool)confirm:(NSString*)title withInfo:(NSString*)info);
JSExportAs(dropdownPrompt, - (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items);
JSExportAs(setUserDefault, - (void)setUserDefault:(NSString*)settingName setting:(id)value);
JSExportAs(getUserDefault, - (id)getUserDefault:(NSString*)settingName);
JSExportAs(openFile, - (void)openFile:(NSArray*)formats callBack:(JSValue*)callback);
JSExportAs(htmlPanel, - (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback);
@end

// Interfacing with the document
@protocol BeatScriptingDelegate <NSObject>
@property (strong, nonatomic) ContinousFountainParser *parser;
@property (weak, readonly) NSWindow *thisWindow;
- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;
- (void)scrollTo:(NSInteger)location;
- (void)scrollToLineIndex:(NSInteger)index;
- (void)scrollToSceneIndex:(NSInteger)index;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)removeRange:(NSRange)range;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
@end

@interface BeatScriptParser : NSObject <BeatScriptingExports, WKScriptMessageHandler>
@property (weak) id<BeatScriptingDelegate> delegate;
@property (nonatomic) NSString* pluginName;

- (void)runScript:(NSString*)string withName:(NSString*)name;
- (void)runScriptWithString:(NSString*)string;
- (void)log:(NSString*)string;

@end

NS_ASSUME_NONNULL_END
