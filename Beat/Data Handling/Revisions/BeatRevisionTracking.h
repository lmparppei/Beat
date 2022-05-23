//
//  BeatRevisionTracking.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"
#import "BeatEditorDelegate.h"
#import "BeatRevisionItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatRevisionTracking : NSObject
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser includeRevisions:(NSArray*)includedRevisions;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string parser:(ContinuousFountainParser*)parser;
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string;
+ (NSMutableDictionary*)changedLinesForSaving:(NSArray*)lines;

+ (NSString*)defaultRevisionColor;
+ (NSArray*)revisionColors;
+ (NSDictionary*)revisionMarkers;
+ (bool)isNewer:(NSString*)currentColor than:(NSString*)oldColor;
+ (NSString*)revisionAttribute;


@property (weak) IBOutlet id<BeatEditorDelegate> delegate;

//@property (nonatomic) NSMutableIndexSet *additions;
//@property (nonatomic) NSMutableIndexSet *removals;
- (void)setupRevisions;

- (void)markerAction:(RevisionType)type;
//- (void)markRangeAsAddition:(NSRange)range;
//- (void)markRangeForRemoval:(NSRange)range;
//- (void)clearReviewMarkers:(NSRange)range;

- (void)nextRevision;
- (void)previousRevision;

- (void)commitRevisions;

@end

NS_ASSUME_NONNULL_END
