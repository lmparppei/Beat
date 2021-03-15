//
//  BeatReviewItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
	ReviewNone = 0,
	ReviewAddition,
	ReviewRemoval,
	ReviewComment
} ReviewType;

@interface BeatReviewItem : NSObject
@property (nonatomic) ReviewType type;
@property (nonatomic) NSString *text;
+ (BeatReviewItem*)type:(ReviewType)type;
- (NSString*)key;
- (NSString*)description;
@end

NS_ASSUME_NONNULL_END
