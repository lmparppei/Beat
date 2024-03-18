//
//  BeatNotifications.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.7.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatNotifications.h"
#import "BeatAppDelegate.h"

@interface BeatNotifications ()
@property (nonatomic) NSMutableArray *shownNotifications;
@end
@implementation BeatNotifications

-(instancetype)init {
	self = [super init];
	[self registerCategories];
	
	self.shownNotifications = [NSMutableArray array];
	
	return self;
}

- (void)showNotification:(NSString*)title body:(NSString*)body identifier:(NSString*)identifier oneTime:(BOOL)showOnce interval:(CGFloat)interval {
	if (@available(macOS 10.14, *)) {
		if (showOnce) {
			// Show this notification only once
			if ([_shownNotifications containsObject:identifier]) return;
			[self.shownNotifications addObject:identifier];
		}
		
		UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
		center.delegate = self;
		
		UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
		content.title = title;
		content.body = body;
		content.categoryIdentifier = identifier;
		
		UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.5 + interval repeats:NO];
		
		UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:content trigger:trigger];
		[center addNotificationRequest:request withCompletionHandler:nil];
	}
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler  API_AVAILABLE(macos(10.14)){
	if ([response.actionIdentifier isEqualToString:@"ShowPluginUpdates"]) {
		[(BeatAppDelegate*)NSApp.delegate openPluginLibrary:nil];
	}
	completionHandler();
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler  API_AVAILABLE(macos(10.14)) {
	completionHandler(UNNotificationPresentationOptionAlert);
}

-(void)registerCategories {
	if (@available(macOS 10.14, *)) {
		UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
		center.delegate = self;
		
		UNNotificationAction *action = [UNNotificationAction actionWithIdentifier:@"ShowPluginUpdates" title:@"Show" options:UNNotificationActionOptionForeground];
		
		UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"PluginUpdates" actions:@[action] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
		NSSet *set = [NSSet setWithObject:category];
		
		[center setNotificationCategories:set];
	}
}

@end
/*
 
 sä saat mut piiloutumaan
 sä saat mut piiloutumaan
 hiivin yli lattian niin hiljaa
 ettet huomaakaan
 
 jos piiloudun kasvien taa
 sä et huomaa
 jos pukeudun mustaan ja pysyn varjoissa
 ehkä sä et huomaa
 toivon että sä et huomaa
 mua
 
 teen samat virheet aina uudestaan
 samat virheet aina uudestaan
 sä saat mut katoamaan
 sä saat mut katoamaan
 sun tapettien sekaan
 sä saat mut katoamaan
 sä saat mut katoamaan
 
 */
