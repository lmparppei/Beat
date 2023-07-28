//
//  BeatConsole.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
#else
    #import <UIKit/UIKit.h>
#endif

@protocol BeatEditorDelegate;

NS_ASSUME_NONNULL_BEGIN

#if !TARGET_OS_IOS
@interface BeatConsole : NSWindowController <NSMenuDelegate>
#else
@interface BeatConsole : UIViewController
#endif
+ (BeatConsole*)shared;
- (void)openConsole;
- (void)clearConsole;
- (void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName context:(id<BeatEditorDelegate> _Nullable)context;
- (void)logError:(id)error context:(id)context pluginName:(NSString*)name;
@end

NS_ASSUME_NONNULL_END
