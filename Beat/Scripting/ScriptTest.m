//
//  ScriptTest.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "ScriptTest.h"

@implementation NSApplication (ScriptTest)
	- (NSNumber*) ready {
	   return [NSNumber numberWithBool:YES];
   }
@end
