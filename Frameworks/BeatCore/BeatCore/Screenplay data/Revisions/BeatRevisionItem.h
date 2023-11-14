//
//  BeatReviewItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
#else
    #import <UIKit/UIKit.h>
#endif

#if TARGET_OS_IOS
    #define BeatColor UIColor
#else
    #define BeatColor NSColor
#endif

@class BeatRevisionGeneration;

typedef NS_ENUM(NSInteger, RevisionType) {
	RevisionNone,
	RevisionAddition,
	RevisionRemovalSuggestion,
	RevisionCharacterRemoved
};

@interface BeatRevisionItem : NSObject <NSCoding, NSCopying>
@property (nonatomic) RevisionType type;
@property (nonatomic) NSString *colorName;
@property (nonatomic) BeatRevisionGeneration* generation;
+ (BeatRevisionItem*)type:(RevisionType)type color:(NSString*)color;
+ (BeatRevisionItem*)type:(RevisionType)type;
- (instancetype)initWithType:(RevisionType)type generation:(BeatRevisionGeneration*)generation;
- (BeatColor*)backgroundColor;
- (NSString*)key;
- (NSString*)description;
@end
