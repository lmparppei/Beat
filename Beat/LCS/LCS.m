//
// Author: Håvard Fossli <hfossli@agens.no>
// Author: Soroush Khanlou <soroush@khanlou.com>
//
// Copyright (c) 2013 Agens AS (http://agens.no/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "LCS.h"

@implementation LCS

+ (void)compareArray:(NSArray *)a
           withArray:(NSArray *)b
       commonIndexes:(out NSIndexSet **)commonIndexesPointer
      removedIndexes:(out NSIndexSet **)removedIndexesPointer
        addedIndexes:(out NSIndexSet **)addedIndexesPointer
    objectComparison:(BOOL(^)(id objectA, id objectB))objectComparison
{
    return [self compareArray:a withArray:b commonIndexes:commonIndexesPointer updatedIndexes:nil removedIndexes:removedIndexesPointer addedIndexes:addedIndexesPointer objectComparison:^LCSObjectEquallity(id objectA, id objectB) {
        return objectComparison(objectA, objectB) ? LCSObjectEquallityEqual : LCSObjectEquallityUnequal;
    }];
}

+ (void)compareArray:(NSArray *)a
           withArray:(NSArray *)b
       commonIndexes:(out NSIndexSet **)commonIndexesPointer
      updatedIndexes:(out NSIndexSet **)updatedIndexesPointer
      removedIndexes:(out NSIndexSet **)removedIndexesPointer
        addedIndexes:(out NSIndexSet **)addedIndexesPointer
    objectComparison:(LCSObjectEquallity(^)(id objectA, id objectB))objectComparison
{
    [self compareListWithCount:a.count with:b.count commonIndexes:commonIndexesPointer updatedIndexes:updatedIndexesPointer removedIndexes:removedIndexesPointer addedIndexes:addedIndexesPointer objectComparison:^LCSObjectEquallity(NSUInteger indexA, NSUInteger indexB) {
        return objectComparison(a[indexA], b[indexB]);
    }];
}

+ (void)compareListWithCount:(NSUInteger)countA
                        with:(NSUInteger)countB
               commonIndexes:(out NSIndexSet **)commonIndexesPointer
              updatedIndexes:(out NSIndexSet **)updatedIndexesPointer
              removedIndexes:(out NSIndexSet **)removedIndexesPointer
                addedIndexes:(out NSIndexSet **)addedIndexesPointer
            objectComparison:(LCSObjectEquallity(^)(NSUInteger indexA, NSUInteger indexB))objectComparison
{
    NSInteger lengths[countA+1][countB+1];
    LCSObjectEquallity cache[countA+1][countB+1];
    
    for (NSInteger i = countA; i >= 0; i--) {
        for (NSInteger j = countB; j >= 0; j--) {
            if (i == countA || j == countB) {
                lengths[i][j] = 0;
            }
            else {
                LCSObjectEquallity equality = objectComparison(i, j);
                cache[i][j] = equality;
                if (equality != LCSObjectEquallityUnequal) {
                    lengths[i][j] = 1 + lengths[i+1][j+1];
                } else {
                    lengths[i][j] = MAX(lengths[i+1][j], lengths[i][j+1]);
                }
            }
        }
    }
    
    NSMutableIndexSet *commonIndexes = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *updatedIndexes = [NSMutableIndexSet indexSet];
    
    for (NSInteger i = 0, j = 0 ; i < countA && j < countB;) {
        
        LCSObjectEquallity equality = cache[i][j];
        
        NSAssert(^{
            return equality == LCSObjectEquallityUnequal || equality == LCSObjectEquallityEqual || equality == LCSObjectEquallityEqualButUpdated;
        }(), @"The cache should be filled up and these values should be the only valid values. Received %i", (int)equality);
        
        if (equality == LCSObjectEquallityEqual) {
            [commonIndexes addIndex:i];
            i++; j++;
        }
        else if (equality == LCSObjectEquallityEqualButUpdated) {
            [commonIndexes addIndex:i];
            [updatedIndexes addIndex:i];
            i++; j++;
        } else if (lengths[i+1][j] >= lengths[i][j+1]) {
            i++;
        } else {
            j++;
        }
    }
    
    if (commonIndexesPointer) {
        *commonIndexesPointer = commonIndexes;
    }
    
    if (updatedIndexesPointer) {
        *updatedIndexesPointer = updatedIndexes;
    }
    
    if (removedIndexesPointer) {
        NSMutableIndexSet *removedIndexes = [NSMutableIndexSet indexSet];
        
        for (NSInteger i = 0; i < countA; i++) {
            if (![commonIndexes containsIndex:i]) {
                [removedIndexes addIndex:i];
            }
        }
        *removedIndexesPointer = removedIndexes;
    }
    
    if (addedIndexesPointer) {
        
        NSUInteger commonIndexesArray[commonIndexes.count];
        [commonIndexes getIndexes:commonIndexesArray maxCount:commonIndexes.count inIndexRange:nil];

        NSMutableIndexSet *addedIndexes = [NSMutableIndexSet indexSet];
        for (NSInteger i = 0, j = 0; i < commonIndexes.count || j < countB;) {
            if (i < commonIndexes.count && j < countB && cache[commonIndexesArray[i]][j] != LCSObjectEquallityUnequal) {
                i++;
                j++;
            } else {
                [addedIndexes addIndex:j];
                j++;
            }
        }
        
        *addedIndexesPointer = addedIndexes;
    }
}

@end
