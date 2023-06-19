//
//  BeatAttributes.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 29.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 So, what's the purpose?
 
 Any class that uses attributes will register their respective text attribute key at load,
 and when needed, we can check if a given attributed string contains *any* custom
 attributes, without having to use convoluted OR logic.
 
 This was written for copy & pasting text in editor.
  
 */

#import "BeatAttributes.h"

@implementation BeatAttributes

+ (BeatAttributes*)shared {
	static BeatAttributes *sharedAttributes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedAttributes = [[self alloc] init];
	});
	return sharedAttributes;
}

- (id)init {
  if (self = [super init]) {
	  self.keys = NSMutableSet.new;
  }
  return self;
}

+ (void)registerAttribute:(NSString*)key
{
	[BeatAttributes.shared.keys addObject:key];
}

+ (BOOL)containsCustomAttributes:(NSDictionary*)dict
{
	NSMutableSet *keys = BeatAttributes.shared.keys;
	for (NSString* key in dict.allKeys) {
		if ([keys containsObject:key]) {
			return true;
		}
	}
	
	return false;
}

+ (NSDictionary*)stripUnnecessaryAttributesFrom:(NSDictionary*)attrs
{
    NSMutableDictionary* dict = NSMutableDictionary.new;
    for (NSString* key in BeatAttributes.shared.keys) {
        if (attrs[key] == nil) continue;
        
        dict[key] = attrs[key];
    }
    
    return dict;
}

@end
