//
//  NSDictionary+Values.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.8.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Convenience methods for storing NSNumber values into a dictionary
 
 */

#import "NSDictionary+Values.h"

@implementation NSDictionary (Values)

-(void)setBool:(BOOL)value key:(NSString*)key {
	[self setValue:[NSNumber numberWithBool:value] forKey:key];
}
-(bool)boolFor:(NSString*)key {
	return [(NSNumber*)[self valueForKey:key] boolValue];
}

-(void)setInt:(NSInteger)value key:(NSString*)key {
	[self setValue:[NSNumber numberWithInteger:value] forKey:key];
}
-(NSInteger)intFor:(NSString*)key {
	return [(NSNumber*)[self valueForKey:key] integerValue];
}

-(void)setFloat:(CGFloat)value key:(NSString*)key {
	[self setValue:[NSNumber numberWithFloat:value] forKey:key];
}
-(CGFloat)floatFor:(NSString*)key {
	return [(NSNumber*)[self valueForKey:key] floatValue];
}

@end
