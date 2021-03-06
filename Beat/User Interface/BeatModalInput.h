//
//  BeatModalInput.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.12.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatModalInput : NSObject
- (void)inputBoxWithMessage:(NSString*)message text:(NSString*)infoText placeholder:(NSString*)placeholder forWindow:(NSWindow*)window completion:(void (^)(NSString *result))completion;
@end

NS_ASSUME_NONNULL_END
