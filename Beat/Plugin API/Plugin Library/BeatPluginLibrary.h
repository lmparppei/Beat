//
//  BeatPluginLibrary.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatPluginLibrary : NSWindowController <NSOutlineViewDelegate, WKScriptMessageHandler>
@property (nonatomic, weak) IBOutlet NSOutlineView *pluginView;
- (void)show;
- (void)clearWebView;
- (void)downloadComplete:(NSString*)pluginName;
@end

NS_ASSUME_NONNULL_END
