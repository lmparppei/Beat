//
//  NSString+LongestCommonSubsequence.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16/11/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <AppKit/AppKit.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (LongestCommonSubsequence)
- (NSArray *) lcsDiff:(NSString *)string;
- (NSString *) longestCommonSubsequence:(NSString*)string;
- (NSString *)longestCommonSubstring:(NSString *)substring;
@end

NS_ASSUME_NONNULL_END
