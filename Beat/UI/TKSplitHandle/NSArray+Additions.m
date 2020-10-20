//
//  NSArray+Additions.m
//  TKSplitHandle
//
//  Created by Antoine Duchateau on 16/06/15.
//  Copyright (c) 2015 Taktik SA. All rights reserved.
//

#import "NSArray+Additions.h"

@implementation NSArray (Additions)
- (NSArray *)arrayByRemovingObjectsFromArray:(NSArray *) objects {
    NSMutableArray *newArray = [NSMutableArray arrayWithArray:self];
    for (id obj in objects) {
        [newArray removeObject:obj];
    }
    return newArray;
}


@end
