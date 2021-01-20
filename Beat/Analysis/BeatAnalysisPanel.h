//
//  BeatAnalysisPanel.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.1.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "ContinousFountainParser.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BeatAnalysisDelegate <NSObject>
@property (nonatomic) NSMutableDictionary *characterGenders;
@end

@interface BeatAnalysisPanel : NSWindowController <WKScriptMessageHandler, WKNavigationDelegate>
@property (weak) id<BeatAnalysisDelegate> delegate;
- (instancetype)initWithParser:(ContinousFountainParser*)parser delegate:(id<BeatAnalysisDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
