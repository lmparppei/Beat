//
//  NSArray+BinarySearch.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.10.2024.
//

#import "NSArray+BinarySearch.h"

@implementation NSArray (BinarySearch)

- (NSUInteger)binarySearchForItem:(id)targetItem matchingIntegerValueFor:(NSString*)key
{
    NSInteger min = 0;
    NSInteger max = self.count - 1;
    
    NSInteger targetValue = ((NSNumber*)[targetItem valueForKey:key]).integerValue;
    
    while (min <= max) {
        NSInteger idx = min + (max - min) / 2;
        id item = self[idx];
        
        NSInteger value = ((NSNumber*)[item valueForKey:key]).integerValue;
        
        if (value == targetValue || item == targetItem) {
            return idx;
        } else if (value < targetValue) {
            min = idx + 1;
        } else {
            max = idx - 1;
        }
    }
    
    return NSNotFound;
}

- (NSUInteger)binarySearchWithLocation:(NSInteger)location inLocationOfRangeValueFor:(NSString*)key
{
    NSInteger min = 0;
    NSInteger max = self.count - 1;
    
    while (min <= max) {
        NSInteger idx = min + (max - min) / 2;
        id item = self[idx];
        
        NSRange range = ((NSNumber*)[item valueForKey:key]).rangeValue;
        
        if (NSLocationInRange(location, range)) {
            return idx;
        } else if (range.location < location) {
            min = idx + 1;
        } else {
            max = idx - 1;
        }
    }
    
    return NSNotFound;
}

@end
