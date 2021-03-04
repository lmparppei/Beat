//
//  BeatTagItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatTagItem.h"
#import "BeatTagging.h"
#import "Line.h"

@implementation BeatTagItem

+ (BeatTagItem*)withString:(NSString*)string type:(BeatTagType)type range:(NSRange)range {
	return [[BeatTagItem alloc] initWithString:string type:type range:range];
}

- (instancetype)initWithString:(NSString*)string type:(BeatTagType)type range:(NSRange)range
{
	self = [super init];
	
	if (self) {
		_type = type;
		_name = string;
		_indices = [NSMutableIndexSet indexSet];
		[_indices addIndexesInRange:range];
	}
	return self;
}

- (NSString*)key {
	return [BeatTagging keyFor:self.type];
}
- (NSColor*)color {
	return [BeatTagging colorFor:self.type];
}
- (void)addRange:(NSRange)range {
	[_indices addIndexesInRange:range];
}

- (NSArray*)rangesAsArray
{
	NSMutableArray *ranges = [NSMutableArray array];
	[_indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[ranges addObject:[NSValue valueWithRange:range]];
	}];
	
	return ranges;
}

- (bool)inRange:(NSRange)range
{
	return [_indices containsIndexesInRange:range];
}

- (NSArray*)ranges
{
	NSMutableArray *ranges = [NSMutableArray array];
	[_indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[ranges addObject:[NSValue valueWithRange:range]];
	}];
	return ranges;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"Tag: %@ - %@ - ranges: %lu", [BeatTagging keyFor:self.type], self.name, [self ranges].count];
}

@end
