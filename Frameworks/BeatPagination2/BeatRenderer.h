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
/// Export settings which carry styles, paper sizes etc.
@property (nonatomic) BeatExportSettings* settings;
/// Not sure why this is just `id` and not the actual class. Dread lightly.
@property (nonatomic, weak) id pagination;

/// Initializes a renderer instance with given export settings. You probably need to update these quite often or reuse the renderer.
- (instancetype)initWithSettings:(BeatExportSettings*)settings;

/// Returns pages rendered as `NSAttributedString` objects.
/// @warning Not compatible with iOS. Can't remember why, probably because of TextBlock compatibility issues.
- (NSArray<NSAttributedString*>*)renderPages:(NSArray<BeatPaginationPage*>*)pages;
/// Renders the whole paginated block and returns an attributed string
- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block firstElementOnPage:(bool)firstElementOnPage;
/// Renders a single line into an attributed string.
- (NSAttributedString*)renderLine:(Line*)line ofBlock:(BeatPaginationBlock* __nullable)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage;
/// Renders a single line, probably __outside__ of screenplay context. Used for debugging and preview effects.
- (NSAttributedString*)renderLine:(Line*)line;

/// Removes all stored styles.
/// @note Styles are not actually reloaded, but loaded on the fly as needed after clearing them.
- (void)reloadStyles;

/// Page number block is created only when rendering the actual pages. This is called by `BeatPaginationPage` during the layout process.
- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page;
/// Returns rendered block point width for given line.
- (CGFloat)blockWidthFor:(Line*)line dualDialogue:(bool)isDualDialogue;
@end

NS_ASSUME_NONNULL_END
