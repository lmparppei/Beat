//
//  BeatVersionControl.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 23.2.2025.
//

#import <Foundation/Foundation.h>

@protocol BeatDocumentDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface BeatVersionControl : NSObject

@property (nonatomic, weak) _Nullable id<BeatDocumentDelegate> delegate;

- (instancetype)initWithDelegate:(id<BeatDocumentDelegate>)delegate;

/// Creates initial commit and stores it in document settings
- (void)createInitialCommit;
/// Commits the current text in document
- (void)addCommit;
/// Removes version control data from the document
- (void)stopVersionControl;

/// Returns the text state at given timestamp, so in other words builds the full text from previous deltas.
/// - note: If you pass a non-timestamp argument or `nil`, you'll probably get the FULL TEXT with all commits. Passing `"base"` will give you the base text.
- (NSString* _Nullable)textAt:(NSString* _Nullable)timestamp;

/// Returns all timestamps from commits
- (NSArray<NSString*>*)timestamps;

@end

NS_ASSUME_NONNULL_END
