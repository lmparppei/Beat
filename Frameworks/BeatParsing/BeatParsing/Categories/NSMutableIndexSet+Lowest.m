//
//  NSMutableIndexSet+Lowest.m
//  Beat
//
//  Created by Hendrik Noeller on 04.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "NSMutableIndexSet+Lowest.h"

@implementation NSMutableIndexSet (Lowest)

- (NSUInteger)lowestIndex
{
    return [self indexGreaterThanOrEqualToIndex:0];
}

@end
