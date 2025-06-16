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

@interface BeatLayoutManager: NSLayoutManager <NSLayoutManagerDelegate>
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)editorDelegate;

@property (nonatomic, weak) id<BeatEditorDelegate> editorDelegate;
//@property (nonatomic) NSDictionary<NSValue*,NSArray<NSNumber*>*>* _Nullable pageBreaks;
@property (nonatomic) NSMapTable<Line*,NSArray*>* _Nullable pageBreaksMap;
- (void)updatePageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> *)pageBreaks;
- (void)ensureLayoutForLinesInRange:(NSRange)range;
@end

NS_ASSUME_NONNULL_END
