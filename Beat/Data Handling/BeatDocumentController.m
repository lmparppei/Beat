//
//  BeatDocumentController.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatDocumentController.h"
#import "BeatAppDelegate.h"

@implementation BeatDocumentController

+ (void)load {
	[BeatDocumentController new];
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
	[super restoreWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
}

@end
