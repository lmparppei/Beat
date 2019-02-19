//
//  OutlineScene.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "ContinousFountainParser.h"

@implementation OutlineScene

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
	_scenes = [[NSMutableArray alloc] init];
	
 /*
	Item * anItem;
	for (int itemIndex = 1; itemIndex <= 50; itemIndex++)
	{
		anItem = [[Item alloc] init];
		anItem.kind = 1;
		[items addObject:anItem];
		[anItem release];
	}
*/
	return self;
}

@end
