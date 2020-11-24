//
//  OutlineScene.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OutlineScene.h"
#import "ContinousFountainParser.h"

@implementation OutlineScene

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
	
	return self;
}
- (NSRange)range {
	return NSMakeRange(self.sceneStart, self.sceneLength);
}
- (NSString*)stringForDisplay {
	return self.line.stringForDisplay;
}
-(NSInteger)timeLength {
	// Welllll... this is a silly implementation, but let's do it.
	// We'll measure scene length purely by the character length, but let's substract the scene heading length
	NSInteger length = self.sceneLength - self.line.string.length + 40;
	if (length < 0) length = 40;
	
	return length;
}

@end
