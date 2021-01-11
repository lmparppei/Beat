//
//  BeatBrowserView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Webkit/Webkit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatBrowserView : NSWindowController <WKScriptMessageHandler>
- (void)showBrowser:(NSURL*)url withTitle:(NSString*)title width:(CGFloat)width height:(CGFloat)height;
@end

NS_ASSUME_NONNULL_END
