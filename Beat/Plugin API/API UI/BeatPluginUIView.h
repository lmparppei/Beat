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

@protocol BeatPluginUIViewExports <JSExport>
JSExportAs(addButton, - (BeatPluginUIButton*)addButton:(NSString*)title action:(JSValue*)action frame:(NSRect)frame);
JSExportAs(htmlView, - (void)addHtmlView:(NSString*)html);
- (void)remove;
- (void)draw:(JSValue*)value;
@end

@interface BeatPluginUIView : NSView <BeatPluginUIViewExports, WKScriptMessageHandler>
@property (nonatomic) WKWebView *webView;
- (instancetype)initWithHeight:(CGFloat)height;
- (void)remove;
@end
