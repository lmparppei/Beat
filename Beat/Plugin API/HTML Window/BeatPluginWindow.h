//
//  BeatPluginWindow.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.5.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "BeatScriptParser.h"

@protocol BeatPluginWindowExports <JSExport>
@property (nonatomic) NSString* title;
JSExportAs(runJS, - (void)runJS:(NSString*)js callback:(JSValue*)callback);
JSExportAs(setFrame, - (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height);
- (CGRect)getFrame;
- (NSSize)screenSize;
- (void)setTitle:(NSString*)title;
- (void)setHTML:(NSString*)html;
- (void)close;
- (void)focus;
@end

@interface BeatPluginWindow : NSPanel <BeatPluginWindowExports, NSWindowDelegate>
@property (nonatomic) WKWebView *webview;
+ (BeatPluginWindow*)withHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height parser:(id)parser;
@end
