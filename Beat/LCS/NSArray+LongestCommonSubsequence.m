//
//  NSArray+LongestCommonSubsequence.m
//  LCS-Objective-C
//
//  Created by Håvard Fossli on 23.06.2016.
//
//

#import "NSArray+LongestCommonSubsequence.h"
#import "LCS.h"

@implementation NSArray (LongestCommonSubsequence)

- (NSIndexSet *)indexesOfCommonElementsWithArray:(NSArray *)array
                                    addedIndexes:(NSIndexSet **)addedIndexes
                                  removedIndexes:(NSIndexSet **)removedIndexes
{
    NSIndexSet *commonIndexes = nil;
    
    [LCS compareArray:self withArray:array commonIndexes:&commonIndexes updatedIndexes:nil removedIndexes:removedIndexes addedIndexes:addedIndexes objectComparison:^LCSObjectEquallity(id objectA, id objectB) {
        return [objectA isEqual:objectB] ? LCSObjectEquallityEqual : LCSObjectEquallityUnequal;
    }];
    return commonIndexes;
}

@end