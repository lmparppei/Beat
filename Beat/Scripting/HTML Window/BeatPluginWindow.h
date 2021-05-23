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
JSExportAs(runJS, - (void)runJS:(NSString*)js callback:(JSValue*)callback);
- (void)setHTML:(NSString*)html;
- (void)close;
@end

@interface BeatPluginWindow : NSPanel <BeatPluginWindowExports, NSWindowDelegate>
@property (nonatomic) WKWebView *webview;
+ (BeatPluginWindow*)withHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height parser:(id)parser;
@end
