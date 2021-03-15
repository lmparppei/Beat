//
//  BeatReviewItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatReviewItem.h"

@implementation BeatReviewItem

-(instancetype)initWithType:(ReviewType)type text:(NSString*)text {
	self = [super init];
	if (self) {
		_type = type;
		_text = text;
	}
	return self;
}
+ (BeatReviewItem*)type:(ReviewType)type
{
	return [[BeatReviewItem alloc] initWithType:type text:@""];
}
- (NSString*)key {
	if (self.type == ReviewRemoval) return @"Removal";
	else if (self.type == ReviewAddition) return @"Addition";
	else if (self.type == ReviewComment) return @"Comment";
	return @"";
}
- (NSString*)description {
	return [NSString stringWithFormat:@"%@", self.key];
}

@end
