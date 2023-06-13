//
//  BeatConsole.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@protocol BeatEditorDelegate;

@interface BeatConsole : NSWindowController <NSMenuDelegate>
+ (BeatConsole*)shared;
- (void)openConsole;
- (void)clearConsole;
- (void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName context:(id<BeatEditorDelegate> _Nullable)context;
- (void)logError:(id)error context:(id)context pluginName:(NSString*)name;
@end

NS_ASSUME_NONNULL_END
