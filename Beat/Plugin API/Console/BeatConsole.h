//
//  BeatConsole.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatConsole : NSObject
+ (BeatConsole*)shared;
-(void)openConsole;
-(void)clearConsole;
-(void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName;
@end

NS_ASSUME_NONNULL_END
