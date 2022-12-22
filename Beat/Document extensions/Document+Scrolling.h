//
//  Document+Scrolling.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Scrolling)

- (void)scrollToSceneNumber:(NSString* __nullable)sceneNumber;
- (void)scrollToScene:(OutlineScene*)scene;
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock;

/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location;
/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line*)line;
/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index;
/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index;
/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
