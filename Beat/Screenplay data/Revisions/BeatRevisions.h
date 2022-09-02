//
//  BeatRevisions.h
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

@interface BeatRevisions : NSResponder
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string includeRevisions:(NSArray*)includedRevisions;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string;
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string;
+ (NSMutableDictionary*)changedLinesForSaving:(NSArray*)lines;

+ (NSString*)defaultRevisionColor;
+ (NSArray*)revisionColors;
+ (NSDictionary*)revisionMarkers;
+ (bool)isNewer:(NSString*)currentColor than:(NSString*)oldColor;
+ (NSString*)attributeKey;

@property (weak) IBOutlet id<BeatEditorDelegate> delegate;

//@property (nonatomic) NSMutableIndexSet *additions;
//@property (nonatomic) NSMutableIndexSet *removals;
- (void)setup;
- (void)registerChangesInRange:(NSRange)range;
- (void)markerAction:(RevisionType)type;
//- (void)markRangeAsAddition:(NSRange)range;
//- (void)markRangeForRemoval:(NSRange)range;
//- (void)clearReviewMarkers:(NSRange)range;

- (void)nextRevision;
- (void)previousRevision;

- (void)commitRevisions;

@end

NS_ASSUME_NONNULL_END
