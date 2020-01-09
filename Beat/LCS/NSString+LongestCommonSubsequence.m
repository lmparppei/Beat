//
//  NSString+LongestCommonSubsequence.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16/11/2019.
//  Based on the work of Jakub Turek, found through Wayback Machine
//

#import <AppKit/AppKit.h>
#import "NSString+LongestCommonSubsequence.h"

@implementation NSString (LongestCommonSubsequence)

- (NSString*) longestCommonSubsequence:(NSString*)string {
  NSUInteger x = self.length;
  NSUInteger y = string.length;

  unsigned int** lengths = malloc((x + 1) * sizeof(unsigned int*));

  for (unsigned int i = 0; i < (x + 1); ++i) {
    lengths[i] = malloc((y + 1) * sizeof(unsigned int));

    for (unsigned int j = 0; j < (y + 1); ++j) {
      lengths[i][j] = 0;
    }
  }

  NSMutableString* lcs = [NSMutableString string];

  for (unsigned int i = 0; i < x; ++i) {
    for (unsigned int j = 0; j < y; ++j) {

      if ([self characterAtIndex:i] == [string characterAtIndex:j]) {
        lengths[i + 1][j + 1] = lengths[i][j] + 1;
      }
      else {
        lengths[i + 1][j + 1] = MAX(lengths[i + 1][j], lengths[i][j + 1]);
      }
    }
  }

  while (x != 0 && y != 0) {
    if (lengths[x][y] == lengths[x - 1][y]) {
      --x;
    }
    else if (lengths[x][y] == lengths[x][y - 1]) {
      --y;
    }
    else {
      [lcs appendFormat:@"%c", [self characterAtIndex:x - 1]];
      --x;
      --y;
    }
  }

  for (unsigned int i = 0; i < self.length + 1; ++i) {
    free(lengths[i]);
  }

  free(lengths);

  NSMutableString* reversed = [NSMutableString stringWithCapacity:lcs.length];

  for (NSInteger i = lcs.length - 1; i >= 0; --i) {
    [reversed appendFormat:@"%c", [lcs characterAtIndex:i]];
  }

  return reversed;
}

- (NSString *)longestCommonSubstring:(NSString *)substring {
    if (substring == nil || substring.length == 0 || self.length == 0) {
        return nil;
        
    }
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    int maxlen = 0;
    int lastSubsBegin = 0;
    NSMutableString *sequenceBuilder = [NSMutableString string];
        
    for (int i = 0; i < substring.length; i++)
    {
        for (int j = 0; j < self.length; j++)
        {
            unichar substringC = [[substring lowercaseString] characterAtIndex:i];
            unichar stringC = [[self lowercaseString] characterAtIndex:j];

            if (substringC != stringC) {
                [map setObject:[NSNumber numberWithInt:0] forKey:[NSString stringWithFormat:@"%i%i",i,j]];
            }
            else {
                if ((i == 0) || (j == 0)) {
                    [map setObject:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"%i%i",i,j]];
                }
                else {
                    int prevVal = [[map objectForKey:[NSString stringWithFormat:@"%i%i",i-1,j-1]] intValue];
                    [map setObject:[NSNumber numberWithInt:1+prevVal] forKey:[NSString stringWithFormat:@"%i%i",i,j]];
                }
                int currVal = [[map objectForKey:[NSString stringWithFormat:@"%i%i",i,j]] intValue];
                if (currVal > maxlen) {
                    maxlen = currVal;
                    int thisSubsBegin = i - currVal + 1;
                    if (lastSubsBegin == thisSubsBegin)
                    {//if the current LCS is the same as the last time this block ran
                        NSString *append = [NSString stringWithFormat:@"%C",substringC];
                        [sequenceBuilder appendString:append];
                    }
                    else //this block resets the string builder if a different LCS is found
                    {
                        lastSubsBegin = thisSubsBegin;
                        NSString *resetStr = [substring substringWithRange:NSMakeRange(lastSubsBegin, (i + 1) - lastSubsBegin)];
                        sequenceBuilder = [NSMutableString stringWithFormat:@"%@",resetStr];
                    }
                }
            }
        }
    }
    return [sequenceBuilder copy];
}

- (NSArray *) lcsDiff:(NSString *)string
{
	// Get longest common subsequence
    NSString *lcs = [self longestCommonSubstring:string];
	NSUInteger l1 = [self length];
    NSUInteger l2 = [string length];
    NSUInteger lc = [lcs length];
	
    NSUInteger idx1 = 0;
    NSUInteger idx2 = 0;
    NSUInteger idxc = 0;
	
    NSMutableString *s1 = [[NSMutableString alloc]initWithCapacity:l1];
    NSMutableString *s2 = [[NSMutableString alloc]initWithCapacity:l2];
    NSMutableArray *res = [NSMutableArray array];
    
	NSInteger pos = -1;
	
	for (;;) {
		pos++;
		
		// If id is longer than LCS length, exit loop
        if (idxc >= lc) break;
		
        unichar c1 = [self characterAtIndex:idx1];
        unichar c2 = [string characterAtIndex:idx2];
        unichar cc = [lcs characterAtIndex:idxc];
		
        if ((c1==cc) && (c2 == cc)) {
            if ([s1 length] || [s2 length]) {
                // We will return an array with following stuff:
				// - Index where the diff was detected (in the original string)
				// - Original string
				// - Changed string
				NSArray *e = @[ [NSNumber numberWithUnsignedInteger:pos], s1, s2];
                [res addObject:e];
                s1 = [[NSMutableString alloc]initWithCapacity:l1];
                s2 = [[NSMutableString alloc]initWithCapacity:l1];
            }
            idx1++; idx2++; idxc++;
            continue;
        }
        if (c1 != cc) {
            [s1 appendString:[NSString stringWithCharacters:&c1 length:1]];
            idx1++;
        }
        if (c2 != cc) {
            [s2 appendString:[NSString stringWithCharacters:&c2 length:1]];
            idx2++;
        }
    }
    if (idx1<l1) {
        [s1 appendString:[self substringFromIndex:idx1]];
    }
    if (idx2<l2) {
        [s2 appendString:[string substringFromIndex:idx2]];
    }
    if ([s1 length] || [s2 length]) {
		NSArray *e = @[ [NSNumber numberWithUnsignedInteger:1], s1, s2];
        [res addObject:e];
    }
    return res;
}


@end
