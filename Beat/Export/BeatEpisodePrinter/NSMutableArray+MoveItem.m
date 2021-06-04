//
//  NSMutableArray+MoveItem.m
//  TableReorganizeTest
//
//  Created by Lauri-Matti Parppei on 24.11.2020.
//

#import "NSMutableArray+MoveItem.h"

@implementation NSMutableArray (MoveItem)

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    // Optional toIndex adjustment if you think toIndex refers to the position in the array before the move (as per Richard's comment)
    if (fromIndex < toIndex) {
        toIndex--; // Optional
    }

    id object = [self objectAtIndex:fromIndex];
    [self removeObjectAtIndex:fromIndex];
    [self insertObject:object atIndex:toIndex];
}
@end
