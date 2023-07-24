//
//  TestPanel.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatHTMLPanelExports <JSExport>
@property (nonatomic) NSString* title;
@property (nonatomic) bool dark;
@property (nonatomic) BOOL resizable;
JSExportAs(runJS, - (void)runJS:(NSString*)js callback:(JSValue* __nullable)callback);
JSExportAs(setFrame, - (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height);
- (CGRect)getFrame;
- (CGRect)getWindowFrame;
- (NSSize)screenSize;
- (NSRect)screenFrame;
- (void)setTitle:(NSString*)title;
- (void)setHTML:(NSString*)html;
- (void)setRawHTML:(NSString*)html;
- (void)close;
- (void)focus;

- (void)gangWithDocumentWindow;
- (void)detachFromDocumentWindow;
- (void)toggleFullScreen;
- (bool)isFullScreen;

@end

@protocol PluginWindowHost <NSObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply>
@property (readonly) NSString *pluginName;
#if !TARGET_OS_IOS
- (void)gangWithDocumentWindow:(NSWindow*)window;
- (void)detachFromDocumentWindow:(NSWindow*)window;
- (void)closePluginWindow:(id)sender;
- (void)log:(NSString*)string;
#endif
@end

@interface BeatPluginHTMLWindow : NSPanel <BeatHTMLPanelExports>
@property (nonatomic, weak) id<PluginWindowHost> host;
@property (nonatomic) bool isClosing;
@property (nonatomic) JSValue* callback;
@property (nonatomic) bool dark;
@property (nonatomic) BOOL resizable;

@property (nonatomic) WKWebView  * _Nullable webview;

- (instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(id)host;
- (void)closeWindow;
- (void)setTitle:(NSString*)title;
- (void)hide;
- (void)appear;
- (bool)isFullScreen;
@end

NS_ASSUME_NONNULL_END
