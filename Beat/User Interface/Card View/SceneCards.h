//
//  SceneCards.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface SceneCards : NSObject<WKScriptMessageHandler>
@property (weak) IBOutlet id<BeatEditorDelegate> delegate;
@property (nonatomic, weak) IBOutlet WKWebView *cardView;

- (void)reload;
- (void)reloadCardsWithVisibility:(bool)alreadyVisible changed:(NSInteger)changedIndex;
- (void)printCardsWithInfo:(NSPrintInfo*)printInfo;
- (void)removeHandlers;
- (void)setup;


// Public reloading methods
- (void)refreshCards;
- (void)refreshCards:(BOOL)alreadyVisible;
- (void)refreshCards:(BOOL)alreadyVisible changed:(NSInteger)changedIndex;

@end

NS_ASSUME_NONNULL_END
