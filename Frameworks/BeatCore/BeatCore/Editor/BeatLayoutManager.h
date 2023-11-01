//
//  BeatLayoutManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatLayoutManagerDelegate<NSLayoutManagerDelegate>
@property (nonatomic, weak) id<BeatEditorDelegate> editorDelegate;
@end

@interface BeatLayoutManager : NSLayoutManager
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)editorDelegate;
@property (nonatomic, weak) id<BeatEditorDelegate> editorDelegate;

#if TARGET_OS_IOS
@property (weak, nonatomic) id<BeatLayoutManagerDelegate> delegate;
#else
@property (weak, atomic) id<BeatLayoutManagerDelegate> delegate;
#endif

@end

NS_ASSUME_NONNULL_END
