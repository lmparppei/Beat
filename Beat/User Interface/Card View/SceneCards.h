//
//  SceneCards.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "WebPrinter.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SceneCardDelegate <NSObject>

- (NSRange)selectedRange;
- (NSMutableArray*)getOutlineItems;
- (NSMutableArray*)lines;

@end

@interface SceneCards : NSObject
@property (weak) id<SceneCardDelegate> delegate;
@property (nonatomic, weak) WKWebView *cardView;
- (instancetype) initWithWebView:(WKWebView *)webView;
- (void) screenView;


- (void)reload;
- (void)reloadCardsWithVisibility:(bool)alreadyVisible changed:(NSInteger)changedIndex;
- (void)printCardsWithInfo:(NSPrintInfo*)printInfo;

@end

NS_ASSUME_NONNULL_END
