//
//  BeatNotificationDelegate.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 24.7.2023.
//

#ifndef BeatNotificationDelegate_h
#define BeatNotificationDelegate_h

@protocol BeatNotificationDelegate
- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval;
@end

#endif /* BeatNotificationDelegate_h */
