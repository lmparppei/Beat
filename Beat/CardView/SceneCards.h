//
//  SceneCards.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "WebPrinter.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SceneCardDelegate <NSObject>

- (NSRange)selectedRange;
- (NSArray*)getOutlineItems;
- (NSArray*)lines;

@end

@interface SceneCards : NSObject
@property (weak) id<SceneCardDelegate> delegate;
@property (nonatomic, weak) WKWebView *cardView;
@property (nonatomic) WebPrinter *webPrinter;
- (instancetype) initWithWebView:(WKWebView *)webView;
- (void) screenView;


- (void)reload;
- (void)reloadCardsWithVisibility:(bool)alreadyVisible changed:(NSInteger)changedIndex;
- (void)printCardsWithInfo:(NSPrintInfo*)printInfo;

@end

NS_ASSUME_NONNULL_END
