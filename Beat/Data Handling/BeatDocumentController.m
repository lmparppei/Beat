//
//  BeatDocumentController.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentController.h"
#import "BeatAppDelegate.h"

@implementation BeatDocumentController

+ (void)load {
	[BeatDocumentController new];
}

-(void)reopenDocumentForURL:(NSURL *)urlOrNil withContentsOfURL:(NSURL *)contentsURL display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {
	if (!(NSEvent.modifierFlags & NSEventModifierFlagShift)) {
		[super reopenDocumentForURL:urlOrNil withContentsOfURL:contentsURL display:displayDocument completionHandler:completionHandler];
	}
	else {
		completionHandler(nil, NO, [NSError errorWithDomain:NSCocoaErrorDomain code:userCanceledErr userInfo:nil]);
	}
}

@end
