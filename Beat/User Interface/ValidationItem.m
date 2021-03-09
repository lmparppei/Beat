//
//  MenuItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "ValidationItem.h"

@implementation ValidationItem
+ (ValidationItem*)newItem:(NSString*)title setting:(NSString*)setting target:(id)target {
	return [[ValidationItem alloc] initWithTitle:title setting:setting target:target];
}
- (instancetype)initWithTitle:(NSString*)title setting:(NSString*)setting target:(id)target {
	self = [super init];
	if (self) {
		_title = title;
		_setting = setting;
		_target = target;
	}
	return self;
}

- (bool)validate {	
	if ([(NSNumber*)[_target valueForKey:_setting] integerValue]) return YES;
	else return NO;
}

@end
