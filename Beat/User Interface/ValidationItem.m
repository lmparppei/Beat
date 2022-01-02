//
//  MenuItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
/*
 
 This class validates menu values from either document instance or document settings object
 and returns YES/NO.
 
 */

#import "ValidationItem.h"
#import "BeatDocumentSettings.h"

@implementation ValidationItem
+ (ValidationItem*)withAction:(SEL)selector setting:(NSString*)setting target:(id)target {
	return [[ValidationItem alloc] initWithSelector:selector setting:setting target:target];
}
+ (ValidationItem*)newItem:(NSString*)title setting:(NSString*)setting target:(id)target {
	return [[ValidationItem alloc] initWithTitle:title setting:setting target:target];
}
- (instancetype)initWithSelector:(SEL)selector setting:(NSString*)setting target:(id)target {
	self = [super init];
	if (self) {
		//_title = [NSString stringWithString:title];
		_selector = selector;
		_setting = setting;
		_target = target;
	}
	return self;
}
- (instancetype)initWithTitle:(NSString*)title setting:(NSString*)setting target:(id)target {
	self = [super init];
	if (self) {
		_title = [NSString stringWithString:title];
		_setting = setting;
		_target = target;
	}
	return self;
}

- (bool)validate {
	NSInteger value = 0;
	
	if ([[self.target className] isEqualToString:@"BeatDocumentSettings"]) {
		// Document settings
		value = [(BeatDocumentSettings*)_target getBool:_setting];
	} else {
		// App settings
		value = [(NSNumber*)[_target valueForKey:_setting] integerValue];
	}
	
	if (value) return YES;
	else return NO;
}

@end
