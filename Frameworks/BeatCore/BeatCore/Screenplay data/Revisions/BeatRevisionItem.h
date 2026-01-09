//
//  BeatReviewItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

@class BeatRevisionGeneration;

typedef NS_ENUM(NSInteger, RevisionType) {
	RevisionNone,
	RevisionAddition,
	RevisionRemovalSuggestion,
	RevisionCharacterRemoved
};

@interface BeatRevisionItem : NSObject <NSCoding, NSCopying>

@property (nonatomic) RevisionType type;
@property (nonatomic) NSInteger generationLevel;

+ (BeatRevisionItem*)type:(RevisionType)type generation:(NSInteger)level;
- (instancetype)initWithType:(RevisionType)type generation:(NSInteger)level;

- (NSString*)keyName;
- (NSString*)description;

@end
