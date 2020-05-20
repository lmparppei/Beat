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

@interface SceneCards : NSObject
@property (nonatomic, weak) WKWebView *cardView;
@property (nonatomic) WebPrinter *webPrinter;
- (instancetype) initWithWebView:(WKWebView *)webView;
- (void) screenView;
- (void) showCards:(NSArray*)cards alreadyVisible:(bool)alreadyVisible changedIndex:(NSInteger)changedIndex;
- (void) printCards:(NSArray*)cards printInfo:(NSPrintInfo*)printInfo;
@end

NS_ASSUME_NONNULL_END
