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

@protocol BeatRevisionDelegate
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range;
@end

@protocol BeatRevisionExports <JSExport>
- (void)addRevision:(NSRange)range color:(NSString*)color;
- (void)removeRevision:(NSRange)range;
- (void)setup;
@end

@interface BeatRevisionGeneration: NSObject
@property (nonatomic) NSString* color;
@property (nonatomic) NSString* marker;
@end

#if TARGET_OS_IOS
@interface BeatRevisions: NSObject <BeatRevisionExports>
#else
@interface BeatRevisions: NSResponder <BeatRevisionExports>
#endif
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string includeRevisions:(NSArray*)includedRevisions;
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string;
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string;
+ (NSMutableDictionary*)changedLinesForSaving:(NSArray*)lines;

+ (NSString*)defaultRevisionColor;
+ (NSArray<NSString*>*)revisionColors;
+ (NSArray<BeatRevisionGeneration*>*)revisionGenerations;
+ (NSDictionary*)revisionLevels;
+ (NSDictionary<NSString*, NSString*>*)revisionMarkers;
+ (bool)isNewer:(NSString*)currentColor than:(NSString*)oldColor;
+ (NSString*)attributeKey;

@property (weak) IBOutlet id<BeatEditorDelegate> _Nullable delegate;

/// Use this as a bridge when no editor is present. Can be null.
@property (weak) IBOutlet id<BeatRevisionDelegate> _Nullable revisionDelegate;

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
- (void)setup;
- (void)loadRevisions;
- (void)registerChangesInRange:(NSRange)range;
- (void)registerChangesWithLocation:(NSInteger)location length:(NSInteger)length delta:(NSInteger)delta;
- (void)markerAction:(RevisionType)type;
- (void)fixRevisionAttributesInRange:(NSRange)fullRange;

- (void)nextRevision;
- (void)previousRevision;

- (void)commitRevisions;

- (void)addRevision:(NSRange)range color:(NSString*)color;
- (void)removeRevision:(NSRange)range;

- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen;
- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen range:(NSRange)convertedRange;
- (void)downgradeFromRevisionIndex:(NSInteger)genIndex;

@end

NS_ASSUME_NONNULL_END
