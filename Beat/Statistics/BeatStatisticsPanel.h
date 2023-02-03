//
//  BeatAnalysisPanel.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <BeatCore/BeatEditorDelegate.h>
@class ContinuousFountainParser;

NS_ASSUME_NONNULL_BEGIN

@interface BeatStatisticsPanel : NSWindowController <WKScriptMessageHandler, WKNavigationDelegate>
@property (weak) id<BeatEditorDelegate> delegate;
- (instancetype)initWithParser:(ContinuousFountainParser*)parser delegate:(id<BeatEditorDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
