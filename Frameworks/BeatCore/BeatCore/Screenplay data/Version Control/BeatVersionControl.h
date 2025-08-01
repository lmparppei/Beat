//
//  BeatVersionControl.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 23.2.2025.
//

#import <Foundation/Foundation.h>

@protocol BeatEditorDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface BeatVersionControl : NSObject
/// Returns the document settings key for version control
+ (NSString*)settingKey;
/// Returns the timestamp format
+ (NSString*)dateFormat;

@property (nonatomic, weak) _Nullable id<BeatEditorDelegate> delegate;
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;

/// Returns `true` if a version control JSON exists
- (bool)hasVersionControl;
/// Creates initial commit and stores it in document settings
- (void)createInitialCommit;
/// Commits the current text in document (no message)
- (void)addCommit;
/// Commits the current text in document with given message. Set  `message` to `nil` to commit without a message.
- (void)addCommitWithMessage:(NSString* _Nullable)message;
/// Removes version control data from the document
- (void)stopVersionControl;
/// Reverts to given version and returns the full text
- (NSString* _Nullable)revertTo:(NSString*)timestamp;

- (BOOL)hasUncommittedChanges;

/// Checks the health of the version control dictionary. `false` means something is wrong and you need to do some actions.
- (bool)doHealthCheck;

/// Returns the text state at given timestamp, so in other words builds the full text from previous deltas.
/// - note: If you pass a non-timestamp argument or `nil`, you'll probably get the FULL TEXT with all commits. Passing `"base"` will give you the base text.
- (NSString* _Nullable)textAt:(NSString* _Nullable)timestamp;

/// Returns all timestamps from commits
- (NSArray<NSString*>*)timestamps;

- (NSString* _Nullable)latestTimestamp;

/// Returns commit dictionary with given timestamp
- (NSDictionary* _Nullable)getCommitWithTimestamp:(NSString*)timestamp;
/// Returns an array of all commits
- (NSArray<NSDictionary*>*)commits;
/// Returns the FULL, mutable version control dictionary
- (NSMutableDictionary*)versionControlDictionary;

/// Automatically generates revised ranges in current document based on the given timestamp
- (void)generateRevisedRangesFrom:(NSString*)timestamp generation:(NSInteger)generation;
/// Automatically generates revised ranges in current document based on the given text
- (void)generateRevisedRangesFromText:(NSString *)oldText generation:(NSInteger)generation;

@end

NS_ASSUME_NONNULL_END
