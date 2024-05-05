//
//  BeatRevisions.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatEditorDelegate.h>
#import <BeatCore/BeatRevisionItem.h>
#import <JavaScriptCore/JavaScriptCore.h>


NS_ASSUME_NONNULL_BEGIN

@protocol BeatRevisionExports <JSExport>
- (void)addRevision:(NSRange)range generation:(NSInteger)generation;
- (void)addRevision:(NSRange)range color:(NSString*)color;
- (void)removeRevision:(NSRange)range;
- (void)setup;
@end

@interface BeatRevisionGeneration: NSObject
@property (nonatomic) NSString* color;
@property (nonatomic) NSInteger level;
@property (nonatomic) NSString* marker;
@end

#if TARGET_OS_IOS
@interface BeatRevisions: NSObject <BeatRevisionExports>
#else
@interface BeatRevisions: NSResponder <BeatRevisionExports>
#endif
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string includeRevisions:(nonnull NSIndexSet*)includedRevisions;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string;
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string;

// + (NSString*)defaultRevisionColor;
// + (NSArray<NSString*>*)revisionColors;
/// Returns an array of the old-school legacy revision colors for converting.
+ (NSArray<NSString*>*)legacyRevisions;

/// Returns an index set with every possible revision index
+ (NSIndexSet*)everyRevisionIndex;

+ (NSArray<BeatRevisionGeneration*>*)revisionGenerations;
+ (NSString*)attributeKey;

@property (weak) IBOutlet id<BeatEditorDelegate> _Nullable delegate;

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
- (void)setup;
- (void)loadRevisions;

/// Because Apple changed something in macOS Sonoma, we need to queue changes when characters are edited AND then apply those changes if needed. Oh my fucking god.
- (void)queueRegisteringChangesInRange:(NSRange)range delta:(NSInteger)delta;
- (void)applyQueuedChanges;

- (void)registerChangesInRange:(NSRange)range;
- (void)registerChangesInRange:(NSRange)range delta:(NSInteger)delta;
- (void)markerAction:(RevisionType)type;
- (void)fixRevisionAttributesInRange:(NSRange)fullRange;

- (void)nextRevision;
- (void)previousRevision;

- (void)commitRevisions;

- (void)addRevision:(NSRange)range generation:(NSInteger)generation;
//- (void)addRevision:(NSRange)range color:(NSString*)color;
- (void)removeRevision:(NSRange)range;

- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen;
- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen range:(NSRange)convertedRange;
- (void)downgradeFromRevisionIndex:(NSInteger)genIndex;

@end

NS_ASSUME_NONNULL_END
