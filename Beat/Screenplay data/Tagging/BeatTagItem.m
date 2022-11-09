//
//  BeatTagItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "BeatTagItem.h"
#import "BeatTagging.h"

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
- (TagColor*)color {
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

#pragma mark - Debugging

-(NSString *)description
{
	return [NSString stringWithFormat:@"Tag: %@ - %@ - ranges: %lu", [BeatTagging keyFor:self.type], self.name, [self ranges].count];
}

#pragma mark - Copy & coding

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatTagItem *item = [[self.class allocWithZone:zone] init];
	item->_type = self.type;
	item->_name = [self.name copyWithZone:zone];
	item->_indices = [self.indices copyWithZone:zone];
	return item;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.name forKey:@"name"];
	[coder encodeObject:self.indices forKey:@"indices"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	
	if (self) {
		_type = [coder decodeIntegerForKey:@"type"];
		_name = [coder decodeObjectForKey:@"name"];
		// NOTE NOTE NOTE: This won't work when copy-pasting, so please dread lightly
		_indices = [coder decodeObjectForKey:@"indices"];
	}
	
	return self;
}

@end
