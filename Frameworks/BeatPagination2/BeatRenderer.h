//
//  BeatRenderer.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <BeatPagination2/BeatPagination.h>
#import <BeatCore/BeatCore.h>

@class BeatPaginationManager;
@class BeatPaginationPage;
@class BeatPaginationBlock;
@class BeatExportSettings;
@class Line;

typedef NS_ENUM(NSInteger, BeatHeaderAlignment) {
    BeatHeaderAlignmentLeft = 0,
    BeatHeaderAlignmentCenter,
    BeatHeaderAlignmentRight
};

NS_ASSUME_NONNULL_BEGIN

@interface BeatRenderer : NSObject
@property (nonatomic) BeatExportSettings* settings;
//@property (nonatomic) BeatPaginationManager* pagination;
@property (nonatomic, weak) id pagination;

- (instancetype)initWithSettings:(BeatExportSettings*)settings;

/// Removes all stored styles.
/// @note Styles are not actually reloaded, but loaded on the fly as needed after clearing them.
- (void)reloadStyles;

- (NSArray<NSAttributedString*>*)renderPages:(NSArray<BeatPaginationPage*>*)pages;
- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block firstElementOnPage:(bool)firstElementOnPage;
- (NSAttributedString*)renderLine:(Line*)line ofBlock:(BeatPaginationBlock* __nullable)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage;
- (NSAttributedString*)renderLine:(Line*)line;

- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page;

- (CGFloat)blockWidthFor:(Line*)line dualDialogue:(bool)isDualDialogue;
@end

NS_ASSUME_NONNULL_END
