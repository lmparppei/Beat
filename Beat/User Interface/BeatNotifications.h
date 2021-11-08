//
//  BeatNotifications.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.7.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatNotifications : NSObject <UNUserNotificationCenterDelegate>
- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval;
@end

NS_ASSUME_NONNULL_END
