//
//  OutlineItemProvider.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 1.8.2025.
//

#import <Foundation/Foundation.h>

@class Line;
@class OutlineScene;
@protocol BeatEditorDelegate;

@interface BeatOutlineItemData : NSObject
@property (nonatomic) NSAttributedString* _Nonnull text;
@property (nonatomic) Line* _Nullable line;
@property (nonatomic) NSRange range;
@end

@interface OutlineItemProvider : NSObject
- (instancetype _Nonnull)initWithScene:(OutlineScene* _Nonnull)scene dark:(bool)dark;
@property (nonatomic, weak) id<BeatEditorDelegate> delegate;

/// The heading (including scene numbers etc.) for the outline item
- (NSAttributedString* _Nonnull)heading;

/// Returns ALL items except ones that are turned off
- (NSArray<BeatOutlineItemData*>* _Nonnull)items;

@end
