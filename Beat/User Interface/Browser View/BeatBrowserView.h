//
//  BeatBrowserView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Webkit/Webkit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatBrowserView : NSWindowController <WKScriptMessageHandler, WKNavigationDelegate>
- (void)showBrowser:(NSURL*)url withTitle:(NSString*)title width:(CGFloat)width height:(CGFloat)height onTop:(bool)onTop;
- (void)showBrowserWithString:(NSString*)string withTitle:(NSString*)title width:(CGFloat)width height:(CGFloat)height onTop:(bool)onTop;
- (void)resetWebView;
@end

NS_ASSUME_NONNULL_END
