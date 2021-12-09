//
//  BeatPluginUIView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <Webkit/Webkit.h>
#import "BeatPluginUIButton.h"
#import "BeatPluginUIExports.h"

@protocol BeatPluginUIViewExports <JSExport>
@property (nonatomic, readonly) NSRect frame;

- (void)remove;
- (void)onDraw:(JSValue*)value;
- (void)addElement:(NSView*)view;
- (void)setHeight:(CGFloat)height;

JSExportAs(addButton, - (BeatPluginUIButton*)addButton:(NSString*)title action:(JSValue*)action frame:(NSRect)frame);
JSExportAs(htmlView, - (void)addHtmlView:(NSString*)html);
JSExportAs(rectangle, - (void)rectangle:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth);
JSExportAs(roundedRectangle, - (void)roundedRectangle:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height radius:(CGFloat)radius fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth);
JSExportAs(circle, - (void)circle:(CGFloat)x y:(CGFloat)y radius:(CGFloat)radius fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth);


@end

@interface BeatPluginUIView : NSView <BeatPluginUIViewExports, BeatPluginUIExports, WKScriptMessageHandler>
@property (nonatomic) WKWebView *webView;
- (instancetype)initWithHeight:(CGFloat)height;
- (void)remove;
@end
